#!/bin/bash


##################################################################
# CONFIGURATION
##################################################################

TAIGA_USER_NAME="taiga"
TAIGA_USER_PASSWORD="taiga"

TAIGA_EVENTS_PASSWORD="som3.event"
TAIGA_BACKEND_SECRET_KEY="som3.secretKey"

TAIGA_IP="<IP ADDRESS>"
TAIGA_DOMAIN="taiga.some.one"

TAIGA_WORKING_DIR="/home/${TAIGA_USER_NAME}/"


##################################################################
# CONFIGURATION
##################################################################

##################################################################
# DEFINES
##################################################################

PROFILE_LANGUAGE_VARIABLE="
export LANGUAGE=en_US.UTF-8 
export LANG=en_US.UTF-8 
export LC_ALL=en_US.UTF-8
"

BASH_ALIASES="
alias python=python3
alias pip=pip3
"


TAIGA_BACKEND_SETTINGS_FILE_CONTENT="
from .common import *

MEDIA_URL = \"http://${TAIGA_DOMAIN}/media/\"
STATIC_URL = \"http://${TAIGA_DOMAIN}/static/\"
SITES[\"front\"][\"scheme\"] = \"http\"
SITES[\"front\"][\"domain\"] = \"${TAIGA_DOMAIN}\"

SECRET_KEY = \"${TAIGA_BACKEND_SECRET_KEY}\"

DEBUG = False
PUBLIC_REGISTER_ENABLED = false

DEFAULT_FROM_EMAIL = \"no-reply@example.com\"
SERVER_EMAIL = DEFAULT_FROM_EMAIL

#CELERY_ENABLED = True

EVENTS_PUSH_BACKEND = \"taiga.events.backends.rabbitmq.EventsPushBackend\"
EVENTS_PUSH_BACKEND_OPTIONS = {\"url\": \"amqp://taiga:${TAIGA_EVENTS_PASSWORD}@localhost:5672/taiga\"}

# Uncomment and populate with proper connection parameters
# for enable email sending. EMAIL_HOST_USER should end by @domain.tld
#EMAIL_BACKEND = \"django.core.mail.backends.smtp.EmailBackend\"
#EMAIL_USE_TLS = False
#EMAIL_HOST = \"localhost\"
#EMAIL_HOST_USER = \"\"
#EMAIL_HOST_PASSWORD = \"\"
#EMAIL_PORT = 25

# Uncomment and populate with proper connection parameters
# for enable github login/singin.
#GITHUB_API_CLIENT_ID = \"yourgithubclientid\"
#GITHUB_API_CLIENT_SECRET = \"yourgithubclientsecret\"
"

##################################################################
# DEFINES
##################################################################



echo "[INFO] setting language variables to solve perls language problem ..."
echo "${PROFILE_LANGUAGE_VARIABLE}" >> ~/.profile
source ~/.profile


echo "" && echo "[INFO] updating system ..."
sudo unattended-upgrades --debug cat /var/log/unattended-upgrades/unattended-upgrades.log


echo "" && echo "[INFO] installing essential packages ..."
sudo apt install -y build-essential binutils-doc autoconf flex bison libjpeg-dev
sudo apt install -y libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev
sudo apt install -y automake libtool libffi-dev curl git tmux gettext


echo "" && echo "[INFO] installing nginx ..."
sudo apt install -y nginx


echo "" && echo "[INFO] installing rabbitmq ..."
sudo apt install -y rabbitmq-server redis-server


echo "" && echo "[INFO] installing circus ..."
sudo apt install -y circus


echo "" && echo "[INFO] installing postgresql ..."
sudo apt install -y postgresql-9.5 postgresql-contrib-9.5
sudo apt install -y postgresql-doc-9.5 postgresql-server-dev-9.5


echo "" && echo "[INFO] installing python ..."
sudo apt install -y python3 python3-pip python-dev python3-dev python-pip
sudo apt install -y libxml2-dev libxslt-dev
sudo apt install -y libssl-dev libffi-dev

echo "${BASH_ALIASES}" >> .bash_aliases
source ~/.bashrc


echo "" && echo "[INFO] configuring postgresql ..."
sudo -u postgres createuser ${TAIGA_USER_NAME}
sudo -u postgres createdb ${TAIGA_USER_NAME} -O ${TAIGA_USER_NAME} --encoding='utf-8' --locale=en_US.utf8 --template=template0


echo "" && echo "[INFO] configuring rabbitmq ..."
sudo rabbitmqctl add_user ${TAIGA_USER_NAME} ${TAIGA_EVENTS_PASSWORD}
sudo rabbitmqctl add_vhost ${TAIGA_USER_NAME}
sudo rabbitmqctl set_permissions -p ${TAIGA_USER_NAME} ${TAIGA_USER_NAME} ".*" ".*" ".*"


echo "" && echo "[INFO] creating log folder ./logs/ ..."
mkdir -p ~/logs


echo "" && echo "[INFO] downloading taiga backend ..."
cd ~
git clone https://github.com/taigaio/taiga-back.git taiga-back
cd taiga-back
git checkout stable


echo "" && echo "[INFO] installing python dependencies ..."
pip install --upgrade pip
pip install -r requirements.txt


echo ""
echo "[INFO] populating database with initial basic data ..."
echo "[INFO] IMPORTANT"
echo "[INFO] this creates the default administrator account:"
echo "[INFO] name: admin"
echo "[INFO] pwd: 123123"
python manage.py migrate --noinput
python manage.py loaddata initial_user
python manage.py loaddata initial_project_templates
python manage.py compilemessages
python manage.py collectstatic --noinput


echo "" && echo "[INFO] creating initial backend configuration ..."
echo "${TAIGA_BACKEND_SETTINGS_FILE_CONTENT}" > ~/taiga-back/settings/local.py