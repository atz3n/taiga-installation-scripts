#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

SERVER_DOMAIN="taiga.some.one"

CREATE_SUDO_USER_SCRIPT_PATH="<path to create-sudo-user.sh>"

SUDO_USER_NAME="taiga"


###################################################################################################
# DEFINES
###################################################################################################

CREATE_SUDO_USER_SCRIPT_NAME="create-sudo-user.sh"

INSTALL_TAIGA_SCRIPT_NAME="install-taiga.sh"
INSTALL_TAIGA_SCRIPT_PATH=$(dirname `which $0`)


###################################################################################################
# MAIN
###################################################################################################

scp ${CREATE_SUDO_USER_SCRIPT_PATH}/${CREATE_SUDO_USER_SCRIPT_NAME} root@${SERVER_DOMAIN}: | tee log.txt
ssh -t root@${SERVER_DOMAIN} "chmod 700 ${CREATE_SUDO_USER_SCRIPT_NAME} && ./${CREATE_SUDO_USER_SCRIPT_NAME}" | tee -a log.txt

scp ${INSTALL_TAIGA_SCRIPT_PATH}/${INSTALL_TAIGA_SCRIPT_NAME} ${SUDO_USER_NAME}@${SERVER_DOMAIN}: | tee -a log.txt
ssh -t ${SUDO_USER_NAME}@${SERVER_DOMAIN} "chmod 700 ${INSTALL_TAIGA_SCRIPT_NAME} && ./${INSTALL_TAIGA_SCRIPT_NAME}" | tee -a log.txt