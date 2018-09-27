# taiga-server
repository for taiga server hosting


## Limitation

The installation and update scripts created by `install-taiga.sh` are currently only tested on a x64 machine with Ubuntu 16.04.

The backup scripts created by `install-backup-scripts.sh` are tested on an Raspberry Pi 1 Model B+ with Raspbian stretch.


## Server Installation
There are two ways to install taiga with the `install-taiga.sh` script
1. Way one
    1. create a sudo user
    1. copy `install-taiga.sh` to the new sudo user
    1. login as sudo user via ssh
    1. open `install-taiga.sh` and adapt the configuration to your needs
    1. make script executable `chmod 700 install-taiga.sh`
    1. execute script `./install-taiga.sh`
1. Way two (Works only with a Linux based system)
    1. open `remote-install.sh` on your local machine
    1. adapt the configuration to your needs. **CAUTION**: this script needs the `create-sudo-user.sh` script from the [misc-server-scripts](https://gitea.some.one/Infrastructure/misc-server-scripts) repo
    1. execute `remote-install.sh` on your local machine. It will create a sudo user and executes 'install-taiga.sh' on the taiga server

*Hint:* The installation script configures taiga in the way that it is **not allowed to selfcreate an account**. To **add an user** go to the **admin page:** `<SERVER_DOMAIN>/admin/`, login as admin and add an user. The **default admin account** is **admin** with **password 123123**


## Backups

### Creating

If you want to **create** a backup **manually**, login as sudo user and execute the backup script `./create-bakup.sh`. The backup will be created under: `<BACKUP_FILE_PREFIX>-backup-<unix timestamp>.tar.gz.enc` and can be found inside the backup users persist folder `/home/<BACKUP_USER_NAME>/persist/`. Creating a backup manually is usually not necessary because there is a daemon running which **creates** backups **periodically**. The period time can be configured via the `BACKUP_EVENT` config variable inside the `install-taiga.sh` script.
    

### Persisting

#### Preparation (you can skip this step if you allready set up your backup system)

login as root and **add** the **ssh-rsa public key** of the backup machine via the `add-backup-ssh-key.sh` script.

#### Manually

**scp** with the backup user at the backup machine to taiga server's persist folder `scp <BACKUP_USER_NAME>@<SERVER_DOMAIN>:persist/* /path/to/backup/storage`

#### Automatically

Configure and execute the `install-backup-scripts.sh` on your backup machine (with enabled cronjob). You can force a backup pulling by executing the `<BACKUP_FILE_PREFIX>-pull-backup.sh` script.

### Restoring

#### Preparation (you can skip this step if you allready set up your backup system)

See preparation in Persisting section.

#### Manually

1. **scp** with the backup user at the backup machine to taiga servers restore folder `scp /path/to/backup/storage/<backup name> <BACKUP_USER_NAME>@<SERVER_DOMAIN>:restore/`
1. login as root on the taiga server and execute the `restore-backup.sh` script

#### Via Script

1. Configure and execute the `install-backup-scripts.sh` on your backup machine (if not allready done)
1. execute the `<BACKUP_FILE_PREFIX>-push-backup.sh` script. You can set the backup file as parameter. If you execute it without a parameter, the latest backup will be used.
1. login as root on the taiga server and execute the `restore-backup.sh` script
