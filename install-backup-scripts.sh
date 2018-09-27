#!/bin/bash


###################################################################################################
# CONFIGURATION
###################################################################################################

SERVER_DOMAIN="taiga.some.one"

BACKUP_USER_NAME="taigabackup"
BACKUP_FILE_PREFIX="taiga"

STORE_PATH="~/taiga-backup"
NUMBER_OF_STORED_BACKUPS=14

ENABLE_CRONJOB=true
BACKUP_PULL_EVENT="0 6	* * *" # every day at 06:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)


###################################################################################################
# DEFINES
###################################################################################################

PULL_BACKUP_SCRIPT_CONTENT="
#!/bin/bash


###################################################################################################
# CONFIGURATION
###################################################################################################

BACKUP_USER_NAME=${BACKUP_USER_NAME}
SERVER_DOMAIN=${SERVER_DOMAIN}

STORE_PATH=${STORE_PATH}
NUMBER_OF_STORED_BACKUPS=${NUMBER_OF_STORED_BACKUPS}


###################################################################################################
# DEFINES
###################################################################################################

TMP_FILE=\"\${STORE_PATH}/zzz-tmp.txt\"


###################################################################################################
# MAIN
###################################################################################################

mkdir -p \${STORE_PATH}


# reduce backups to configured number of backups - 1
ls -1 \${STORE_PATH} > \${TMP_FILE}
NUMBER_OF_FILES=\`wc -l < \${TMP_FILE}\`

while [ \${NUMBER_OF_FILES} -gt \${NUMBER_OF_STORED_BACKUPS} ]
do

  LAST_FILE_NAME=\$(head -n 1 \${TMP_FILE})
  rm \"\${STORE_PATH}/\${LAST_FILE_NAME}\"

  ls -1 \${STORE_PATH} > \${TMP_FILE}
  NUMBER_OF_FILES=\`wc -l < \${TMP_FILE}\`

done

rm \${TMP_FILE}


# pull backup
scp \${BACKUP_USER_NAME}@\${SERVER_DOMAIN}:persist/* \${STORE_PATH}
echo \"[INFO] done\"
"


PUSH_BACKUP_SCRIPT_CONTENT="
#!/bin/bash


###################################################################################################
# CONFIGURATION
###################################################################################################

BACKUP_USER_NAME=${BACKUP_USER_NAME}
SERVER_DOMAIN=${SERVER_DOMAIN}

STORE_PATH=${STORE_PATH}


###################################################################################################
# DEFINES
###################################################################################################

TMP_FILE=\"\${STORE_PATH}/aaa-tmp.txt\"


###################################################################################################
# MAIN
###################################################################################################

if [ \$# -eq 0 ]; then
  
  # get latest backup
  ls -1 \${STORE_PATH} > \${TMP_FILE}
  BACKUP_FILE=\$(tail -n 1 \${TMP_FILE})
  rm \${TMP_FILE}
  

  # check if backup exists
  if [[ \${BACKUP_FILE} != ${BACKUP_FILE_PREFIX}-backup-* ]] || [[ \${BACKUP_FILE} != *.tar.gz.enc ]]; then 
    echo \"[ERROR] no backup file found\"
    exit
  fi

elif [ \$# -eq 1  ]; then

  # check if parameter starts with \"${BACKUP_FILE_PREFIX}-backup-\" and ends with \".tar.gz.enc\"
  if [[ \$1 != ${BACKUP_FILE_PREFIX}-backup-* ]] || [[ \$1 != *.tar.gz.enc ]] ; then 
    echo \"[ERROR] backup name does not match backup name style\"
    exit
  fi

  
  BACKUP_FILE=\$1

else

  echo \"[ERROR] to many arguments\"
  exit

fi


# push backup
scp \${STORE_PATH}/\${BACKUP_FILE} \${BACKUP_USER_NAME}@\${SERVER_DOMAIN}:restore/
echo \"[INFO] done\"
"


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] creating backup pulling file ..."
echo "$PULL_BACKUP_SCRIPT_CONTENT" > pull-backup.sh
chmod 700 pull-backup.sh


echo "[INFO] creating backup pushing file ..."
echo "$PUSH_BACKUP_SCRIPT_CONTENT" > push-backup.sh
chmod 700 push-backup.sh


if [ ${ENABLE_CRONJOB} == true ]; then
  echo "[INFO] creating backup pulling job ..."
  (crontab -l 2>>/dev/null; echo "${BACKUP_PULL_EVENT}	/bin/bash ${PWD}/pull-backup.sh") | crontab -
fi


echo "[INFO] done"