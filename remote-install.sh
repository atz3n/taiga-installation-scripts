#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

SERVER_ADDRESS="taiga.some.one"

CREATE_SUDO_USER_SCRIPT_PATH="/home/atzen/someone/Infrastructure/misc-server-scripts/"


###################################################################################################
# DEFINES
###################################################################################################

CREATE_SUDO_USER_SCRIPT_NAME="create-sudo-user.sh"

INSTALL_TAIGA_SCRIPT_NAME="install-taiga.sh"
INSTALL_TAIGA_SCRIPT_PATH=$(dirname `which $0`)


###################################################################################################
# MAIN
###################################################################################################

ssh-keygen -f "/home/atzen/.ssh/known_hosts" -R ${SERVER_ADDRESS}
ssh-keygen -f "/home/atzen/.ssh/known_hosts" -R 104.248.100.108

scp ${CREATE_SUDO_USER_SCRIPT_PATH}/${CREATE_SUDO_USER_SCRIPT_NAME} root@${SERVER_ADDRESS}: | tee log.txt
ssh -t root@${SERVER_ADDRESS} "chmod 700 ${CREATE_SUDO_USER_SCRIPT_NAME} && ./${CREATE_SUDO_USER_SCRIPT_NAME}" | tee -a log.txt

scp ${INSTALL_TAIGA_SCRIPT_PATH}/${INSTALL_TAIGA_SCRIPT_NAME} taiga@${SERVER_ADDRESS}: | tee -a log.txt
ssh -t taiga@${SERVER_ADDRESS} "chmod 700 ${INSTALL_TAIGA_SCRIPT_NAME} && ./${INSTALL_TAIGA_SCRIPT_NAME}" | tee -a log.txt