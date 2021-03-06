## Стенд для резервного копирования.

Цель:

Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client

Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:

- Директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB.
- Репозиторий дле резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение
- Имя бекапа должно содержать информацию о времени снятия бекапа
- Глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов
- Резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации.
- Написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение.
- Настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов


### Реализация.

Запустим стен командой `vagrant up`, все установки произведуться автоматически. Дадим стенду поработать 30 мин. и запустим мониторинг логав.

- [Инструкция по установки borgbackup ](./INSTALL.md)

Запусим мониторинг логфайла
```
[root@client ~]# tail -f /var/log/borg_backup.log 
```
По логам видно как с интервалом 5мин, делаеться бэкап каталога `etc` хоста `client.mydomain.local`. Проверим восстановление из бэкапа. Для демонстрации удалим каталог `/etc/testdir` и востановим из бэкапа.

Перед тем как удалим католог, узнаем имя последнего архива:
```
[root@client ~]# borg list borg@backup-server:/var/backup/$(hostname)-etc
2020-12-13-11-31                     Sun, 2020-12-13 11:31:33 [ef61384ae1b666a7bd747bef7653380b558a144db8cb2e4af68794d451227093]
```
Удалим католог `/etc/testdir`.
```
[root@client ~]# rm -Rfv /etc/testdir
removed '/etc/testdir/lmhosts'
removed '/etc/testdir/smb.conf'
removed '/etc/testdir/smb.conf.example'
removed directory: '/etc/testdir'
```
```
[root@client ~]# ls -la /etc/testdir
ls: cannot access /etc/testdir: No such file or directory
```

Для восстановления, смонтируем последний архив бэкапа в директорию `mnt`:
```
[root@client ~]# borg mount borg@backup-server:/var/backup/$(hostname)-etc::2020-12-13-11-31 /mnt/
```
Вернем testdir в /etc:
```
[root@client ~]# cp -Rp /mnt/etc/testdir /etc
```
```
[root@client ~]# ls -la /etc/testdir
total 32
drwxr-xr-x.  2 root root    61 Dec 13 11:26 .
drwxr-xr-x. 79 root root  8192 Dec 13 11:38 ..
-rw-r--r--.  1 root root    20 Dec 13 11:26 lmhosts
-rw-r--r--.  1 root root   706 Dec 13 11:26 smb.conf
-rw-r--r--.  1 root root 11327 Dec 13 11:26 smb.conf.example
```
Отмонтируем архив бэкапа
```
[root@client ~]# borg umount /mnt
```
