#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

SERVER_DOMAIN="<domain>"

MISC_SERVER_SCRIPTS_PATH="<path to misc-server-script>"

SUDO_USER_NAME="taiga"
SUDO_USER_PWD="taiga"


###################################################################################################
# DEFINES
###################################################################################################

CREATE_SUDO_USER_SCRIPT_NAME="create-sudo-user.sh"

INSTALL_TAIGA_SCRIPT_NAME="install-taiga.sh"
INSTALL_TAIGA_SCRIPT_PATH=$(dirname `which $0`)


###################################################################################################
# MAIN
###################################################################################################


ssh-keygen -f "/home/atzen/.ssh/known_hosts" -R ${SERVER_DOMAIN}
# ssh-keygen -f "/home/atzen/.ssh/known_hosts" -R 104.248.100.108


scp ${MISC_SERVER_SCRIPTS_PATH}/${CREATE_SUDO_USER_SCRIPT_NAME} root@${SERVER_DOMAIN}: | tee log.txt
ssh -t root@${SERVER_DOMAIN} "chmod 700 ${CREATE_SUDO_USER_SCRIPT_NAME} && ./${CREATE_SUDO_USER_SCRIPT_NAME} -u ${SUDO_USER_NAME} -p ${SUDO_USER_PWD}" | tee -a log.txt

scp ${INSTALL_TAIGA_SCRIPT_PATH}/${INSTALL_TAIGA_SCRIPT_NAME} ${SUDO_USER_NAME}@${SERVER_DOMAIN}: | tee -a log.txt
ssh -t ${SUDO_USER_NAME}@${SERVER_DOMAIN} "chmod 700 ${INSTALL_TAIGA_SCRIPT_NAME} && ./${INSTALL_TAIGA_SCRIPT_NAME}" | tee -a log.txt