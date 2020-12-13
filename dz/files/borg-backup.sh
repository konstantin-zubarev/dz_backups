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

