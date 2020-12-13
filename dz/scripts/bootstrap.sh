#!/usr/bin/env bash
# Update hosts file

domen=mydomen.local
hostname_s=backup-server
hostname_c=client
ip_s=192.168.11.101
ip_c=192.168.11.102

disk=$(fdisk -l | grep 5368 | awk -F ':' '{print $1}' | sed 's/\Disk \/dev//')

echo "Update /etc/hosts file"
cat >>/etc/hosts<<EOF
$ip_s $hostname_s.$domen $hostname_s
$ip_c $hostname_c.$domen $hostname_c
EOF

## Install
timedatectl set-timezone Europe/Moscow
yum install -y epel-release
yum install -y borgbackup

if [ "$(hostname)" == $hostname_s.$domen ]; then
	useradd -m borg
	echo password | passwd borg --stdin
        echo y | mkfs.ext4 /dev$disk
	mkdir /var/backup/
	echo /dev$disk       /var/backup/    ext4    defaults        0       1 >>/etc/fstab
	mount -a
	chown -R borg:borg /var/backup
fi

if [ "$(hostname)" == $hostname_c.$domen ]; then
        yum install -y sshpass
	ssh-keygen -b 2048 -t rsa -q -N '' -f ~/.ssh/id_rsa
	sshpass -p password ssh-copy-id -o "StrictHostKeyChecking=no" borg@backup-server
	borg init -e none borg@backup-server:/var/backup/$(hostname)-etc
        cp /vagrant/borg-backup.sh /etc/init.d/borg-backup.sh
	chmod u+x /etc/init.d/borg-backup.sh
        cp /vagrant/borg-backup /etc/logrotate.d/borg-backup
        cp /vagrant/borg-backup.service /etc/systemd/system/borg-backup.service
        cp /vagrant/borg-backup.timer /etc/systemd/system/borg-backup.timer
	mkdir /etc/testdir/
	cp /etc/samba/* /etc/testdir/
        systemctl daemon-reload
        systemctl enable --now borg-backup.service
        systemctl enable --now borg-backup.timer

fi

