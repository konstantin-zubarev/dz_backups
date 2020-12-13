## Установка borgbackup.

### 1. Хост `backup_server`.

#### 1.1. Установим borgbackup на хост `backup_server`.

```
[root@backup-server ~]# yum install -y epel-release
[root@backup-server ~]# yum install -y borgbackup
```

Создадим пользователя borg
```
[root@backup-server ~]# useradd -m borg
[root@backup-server ~]# echo password | passwd borg --stdin
```

Монтируем директорию /var/backup
```
[root@backup-server ~]# mkfs.ext4 /dev/sdb
[root@backup-server ~]# mkdir /var/backup
[root@backup-server ~]# echo /dev/sdb       /var/backup/    ext4    defaults        0       1 >>/etc/fstab
[root@backup-server ~]# mount -a
[root@backup-server ~]# chown -R borg:borg /var/backup
```
Проверим
```
[root@backup-server ~]# df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        489M     0  489M   0% /dev
tmpfs           496M     0  496M   0% /dev/shm
tmpfs           496M  6.8M  489M   2% /run
tmpfs           496M     0  496M   0% /sys/fs/cgroup
/dev/sda1        40G  3.2G   37G   8% /
/dev/sdb        4.8G   20M  4.6G   1% /var/backup
tmpfs           100M     0  100M   0% /run/user/1000
tmpfs           100M     0  100M   0% /run/user/0
```

2. Хост `client`

```
echo 192.168.11.101 backup-server.mydomen.local backup-server >>/etc/hosts
echo 192.168.11.102 client.mydomen.local client >>/etc/hosts
```

1.1. Установим borgbackup на хост `client`.

```
[root@client ~]# yum install -y epel-release
[root@client ~]# yum install -y borgbackup
[root@client ~]# yum install -y sshpass
```

Сгенерируем ключи аутентификации для SSH, и пробросить на `backup_server` хост.
```
[root@client ~]# ssh-keygen -b 2048 -t rsa -q -N '' -f ~/.ssh/id_rsa
```
```
[root@client ~]# sshpass -p password ssh-copy-id -o "StrictHostKeyChecking=no" borg@backup-server
```
Проверим, что подключение по SSH без пароля.
```
[root@client ~]# ssh borg@backup-server
```
Инициализируем репозиторий для бэкапов:
```
[root@client ~]# borg init -e none borg@backup-server:/var/backup/$(hostname)-etc
```
Запустим первый запуск бэкапа
```
[root@client ~]# borg create  -v --stats --progres borg@backup-server:/var/backup/$(hostname)-etc::"{now:%Y-%m-%d-%H-%M}" /etc
```
```
------------------------------------------------------------------------------                
Archive name: 2020-12-12-09-28
Archive fingerprint: 6d96fc2ce0768aec1a0a47f06c8e9d60ff6c0e4f68329d281e558ddb508033c9
Time (start): Sat, 2020-12-12 09:28:13
Time (end):   Sat, 2020-12-12 09:28:15
Duration: 1.43 seconds
Number of files: 1698
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               28.43 MB             13.42 MB             11.79 MB
All archives:               28.43 MB             13.42 MB             11.79 MB

                       Unique chunks         Total chunks
Chunk index:                    1276                 1692
------------------------------------------------------------------------------
```

Скрип для автоматического создания бэкапа
```
[root@client ~]# vi /etc/init.d/borg-backup.sh
```
```
#!/bin/bash
# Client and server name

CLIENT=borg
SERVER=backup-server
TYPEOFBACKUP=etc
REPOSITORY=$CLIENT@$SERVER:/var/backup/$(hostname)-${TYPEOFBACKUP}
LOG="/var/log/borg_backup.log"

# Backup
borg create -v --stats --progres $REPOSITORY::"{now:%Y-%m-%d-%H-%M}" /etc 2>> $LOG

# Afterc backup
borg prune -v --list --dry-run --keep-daily=90 --keep-monthly=12 $REPOSITORY 2>> $LOG

```
```
[root@client ~]# chmod u+x /etc/init.d/borg-backup.sh
```
Добавиим ротацию лога /var/log/borg_backup.log
```
[root@client ~]# vi /etc/logrotate.d/borg-backup
```
```
/var/log/borg_backup.log {
  rotate 5
  missingok
  notifempty
  compress
  size 1M
  daily
  create 0644 root root
  postrotate
    service rsyslog restart > /dev/null
  endscript
}
```
Автоматическое выполнение бэкапа
```
[root@client ~]# vi /etc/systemd/system/borg-backup.service
```
```
[Unit]
Description=Template Settings Service
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/etc/init.d/borg-backup.sh

[Install]
WantedBy=multi-user.target
```
```
[root@client ~]# vi /etc/systemd/system/borg-backup.timer
```
```
[Unit]
Description=Borg backup timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=borg-backup.service

[Install]
WantedBy=multi-user.target
```
```
[root@client ~]# systemctl daemon-reload
[root@client ~]# systemctl enable --now borg-backup.service
[root@client ~]# systemctl enable --now borg-backup.timer
```
Запусим мониторинг логфайла
```
[root@client ~]# tail -f /var/log/borg_backup.log 
```
Ссылка на дополнительную информацию
- [Теория и практика бэкапов с Borg](https://habr.com/ru/company/flant/blog/420055/)
- [Установка и настройка BorgBackup](https://community.hetzner.com/tutorials/install-and-configure-borgbackup/ru?title=BorgBackup/ru)
