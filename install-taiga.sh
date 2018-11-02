#!/bin/bash

#
# This script installs taiga (https://taiga.io) on an ubuntu server.
# It is based on the official installation guide
# (http://taigaio.github.io/taiga-doc/dist/setup-production.html)
#

###################################################################################################
# CONFIGURATION
###################################################################################################

SERVER_DOMAIN="<domain>"
#SERVER_DOMAIN=$(hostname -I | head -n1 | cut -d " " -f1)

TAIGA_EVENTS_PASSWORD="som3.event"
TAIGA_BACKEND_SECRET_KEY="som3.secretKey"

BACKUP_USER_NAME="taigabackup"
BACKUP_FILE_PREFIX="taiga"
BACKUP_EVENT="0 3	* * *" # every day at 03:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)
BACKUP_KEY="dummy1234"

ENABLE_CYCLIC_REBOOT=true # reboot to clear ram
CYCLIC_REBOOT_EVENT="0 5	* * *" # every day at 05:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)

ENABLE_LETSENCRYPT=false
LETSENCRYPT_RENEW_EVENT="30 2	1 */2 *" # At 02:30 on day-of-month 1 in every 2nd month.
                                         # (Every 60 days. That's the default time range from certbot)

RECREATING_DH_PARAMETER=false # strengthens security but takes a long time to generate

ENABLE_EMAIL_NOTIFICATION=false
EMAIL_HOST="smtp.gmail.com"
EMAIL_HOST_USER="pm.some.one@gmail.com"
EMAIL_HOST_PASSWORD="<mail password>"
EMAIL_PORT=465


###################################################################################################
# DEFINES
###################################################################################################

TAIGA_USER_NAME=$(whoami)


PROFILE_LANGUAGE_VARIABLE="
export LANGUAGE=\"en_US.UTF-8\"
export LANG=\"en_US.UTF-8 \"
export LC_ALL=\"en_US.UTF-8\"
export LC_CTYPE=\"en_US.UTF-8\"
"


TAIGA_BACKEND_CONFIG_FILE_CONTENT="
from .common import *

MEDIA_URL = \"https://${SERVER_DOMAIN}/media/\"
STATIC_URL = \"https://${SERVER_DOMAIN}/static/\"
SITES[\"front\"][\"scheme\"] = \"https\"
SITES[\"front\"][\"domain\"] = \"${SERVER_DOMAIN}\"

SECRET_KEY = \"${TAIGA_BACKEND_SECRET_KEY}\"

DEBUG = False
PUBLIC_REGISTER_ENABLED = False

DEFAULT_FROM_EMAIL = \"no-reply@example.com\"
SERVER_EMAIL = DEFAULT_FROM_EMAIL

CELERY_ENABLED = True

EVENTS_PUSH_BACKEND = \"taiga.events.backends.rabbitmq.EventsPushBackend\"
EVENTS_PUSH_BACKEND_OPTIONS = {\"url\": \"amqp://taiga:${TAIGA_EVENTS_PASSWORD}@localhost:5672/taiga\"}

# Uncomment and populate with proper connection parameters
# for enable email sending. EMAIL_HOST_USER should end by @domain.tld
$(if [ ${ENABLE_EMAIL_NOTIFICATION} == true ]; then
    echo "EMAIL_BACKEND = \"django.core.mail.backends.smtp.EmailBackend\""
    echo "EMAIL_USE_TLS = False"
    echo "EMAIL_USE_SSL = True"
    echo "EMAIL_HOST = \"${EMAIL_HOST}\""
    echo "EMAIL_HOST_USER = \"${EMAIL_HOST_USER}\""
    echo "EMAIL_HOST_PASSWORD = \"${EMAIL_HOST_PASSWORD}\""
    echo "EMAIL_PORT = ${EMAIL_PORT}"
fi)

# Uncomment and populate with proper connection parameters
# for enable github login/singin.
#GITHUB_API_CLIENT_ID = \"yourgithubclientid\"
#GITHUB_API_CLIENT_SECRET = \"yourgithubclientsecret\"
"


TAIGA_FRONTEND_CONFIG_FILE_CONTENT="
{
    \"api\": \"https://${SERVER_DOMAIN}/api/v1/\",
    \"eventsUrl\": \"wss://${SERVER_DOMAIN}/events\",
    \"eventsMaxMissedHeartbeats\": 5,
    \"eventsHeartbeatIntervalTime\": 60000,
    \"eventsReconnectTryInterval\": 10000,
    \"debug\": true,
    \"debugInfo\": false,
    \"defaultLanguage\": \"en\",
    \"themes\": [\"taiga\",\"material-design\",\"high-contrast\"],
    \"defaultTheme\": \"taiga\",
    \"publicRegisterEnabled\": false,
    \"feedbackEnabled\": true,
    \"supportUrl\": \"https://tree.taiga.io/support\",
    \"privacyPolicyUrl\": null,
    \"termsOfServiceUrl\": null,
    \"GDPRUrl\": null,
    \"maxUploadFileSize\": null,
    \"contribPlugins\": [],
    \"tribeHost\": null,
    \"importers\": [],
    \"gravatar\": true,
    \"rtlLanguages\": [\"fa\"]
}
"


TAIGA_EVENTS_CONFIG_FILE_CONTENT="
{
    \"url\": \"amqp://taiga:${TAIGA_EVENTS_PASSWORD}@localhost:5672/taiga\",
    \"secret\": \"${TAIGA_BACKEND_SECRET_KEY}\",
    \"webSocketServer\": {
        \"port\": 8888
    }
}
"


CIRCUS_TAIGA_EVENTS_CONFIG_FILE_CONTENT="
[watcher:taiga-events]
working_dir = /home/${TAIGA_USER_NAME}/taiga-events
cmd = /usr/bin/coffee
args = index.coffee
uid = taiga
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/${TAIGA_USER_NAME}/logs/taigaevents.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 12
stderr_stream.class = FileStream
stderr_stream.filename = /home/${TAIGA_USER_NAME}/logs/taigaevents.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 12
"


CIRCUS_TAIGA_BACKEND_CONFIG_FILE_CONTENT="
[watcher:taiga]
working_dir = /home/${TAIGA_USER_NAME}/taiga-back
cmd = gunicorn
args = -w 3 -t 60 --pythonpath=. -b 127.0.0.1:8001 taiga.wsgi
uid = taiga
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/${TAIGA_USER_NAME}/logs/gunicorn.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 4
stderr_stream.class = FileStream
stderr_stream.filename = /home/${TAIGA_USER_NAME}/logs/gunicorn.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 4

[env:taiga]
PATH = /home/${TAIGA_USER_NAME}/.virtualenvs/taiga/bin:\$PATH
TERM=rxvt-256color
SHELL=/bin/bash
USER=${TAIGA_USER_NAME}
LANG=en_US.UTF-8
HOME=/home/${TAIGA_USER_NAME}
PYTHONPATH=/home/${TAIGA_USER_NAME}/.virtualenvs/taiga/lib/python3.5/site-packages
"


CIRCUS_TAIGA_CELERY_CONFIG_FILE_CONTENT="
[watcher:taiga-celery]
working_dir = /home/${TAIGA_USER_NAME}/taiga-back
cmd = celery
args = -A taiga worker -c 4
uid = taiga
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/${TAIGA_USER_NAME}/logs/celery.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 4
stderr_stream.class = FileStream
stderr_stream.filename = /home/${TAIGA_USER_NAME}/logs/celery.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 4

[env:taiga-celery]
PATH = /home/${TAIGA_USER_NAME}/.virtualenvs/taiga/bin:$PATH
TERM=rxvt-256color
SHELL=/bin/bash
USER=${TAIGA_USER_NAME}
LANG=en_US.UTF-8
HOME=/home/${TAIGA_USER_NAME}
PYTHONPATH=/home/${TAIGA_USER_NAME}/.virtualenvs/taiga/lib/python3.5/site-packages
"


NGINX_CONFIGURATION_FILE_CONTENT="
server {
    listen 80 default_server;
    server_name ${SERVER_DOMAIN} \$server_addr;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl default_server;
    server_name ${SERVER_DOMAIN} \$server_addr;

    large_client_header_buffers 4 32k;
    client_max_body_size 50M;
    charset utf-8;

    index index.html;

    access_log /home/${TAIGA_USER_NAME}/logs/nginx.access.log;
    error_log /home/${TAIGA_USER_NAME}/logs/nginx.error.log;

    # Frontend
    location / {
        root /home/${TAIGA_USER_NAME}/taiga-front-dist/dist/;
        try_files \$uri \$uri/ /index.html;
    }

    # Backend
    location /api {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Scheme \$scheme;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:8001/api;
        proxy_redirect off;
    }

    # Django admin access (/admin/)
    location /admin {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Scheme \$scheme;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:8001\$request_uri;
        proxy_redirect off;
    }

    # Static files
    location /static {
        alias /home/${TAIGA_USER_NAME}/taiga-back/static;
    }

    # Media files
    location /media {
        alias /home/${TAIGA_USER_NAME}/taiga-back/media;
    }

	# Taiga-events
	location /events {
	proxy_pass http://127.0.0.1:8888/events;
	proxy_http_version 1.1;
	proxy_set_header Upgrade \$http_upgrade;
	proxy_set_header Connection \"upgrade\";
	proxy_connect_timeout 7d;
	proxy_send_timeout 7d;
	proxy_read_timeout 7d;
	}

    add_header Strict-Transport-Security \"max-age=63072000; includeSubdomains; preload\";
    add_header Public-Key-Pins 'pin-sha256=\"klO23nT2ehFDXCfx3eHTDRESMz3asj1muO+4aIdjiuY=\"; pin-sha256=\"633lt352PKRXbOwf4xSEa1M517scpD3l5f79xMD9r9Q=\"; max-age=2592000; includeSubDomains';

    ssl on;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    # ssl_certificate /etc/nginx/ssl/example.com/ssl-bundle.crt;
    # ssl_certificate_key /etc/nginx/ssl/example.com/example_com.key;
    ssl_session_timeout 5m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK';
    ssl_session_cache shared:SSL:10m;
$(if [ ${RECREATING_DH_PARAMETER} == true ]; then
    echo "    ssl_dhparam /etc/ssl/dhparam.pem;"
fi)
    ssl_stapling on;
    ssl_stapling_verify on;
}
"

BACKUP_SCRIPT_CONTENT="
#!/bin/bash

BACKUP_NAME=\"${BACKUP_FILE_PREFIX}-backup-\$(date +'%s').tar.gz\"


cd /home/${TAIGA_USER_NAME}

echo \"\" > taiga.dump
chmod 666 taiga.dump

sudo -u postgres pg_dump --format=custom --dbname=taiga --file=taiga.dump

sudo bash -c \"rm -f /home/${BACKUP_USER_NAME}/persist/${BACKUP_FILE_PREFIX}-backup-*\"

sudo tar -pcvzf \${BACKUP_NAME} taiga.dump taiga-back/media/ /home/${BACKUP_USER_NAME}/.ssh/authorized_keys
sudo openssl enc -aes-256-cbc -e -in \${BACKUP_NAME} -out /home/${BACKUP_USER_NAME}/persist/\"\${BACKUP_NAME}.enc\" -kfile backup-key.txt

rm -f taiga.dump
rm -f \${BACKUP_NAME}

sudo chown ${BACKUP_USER_NAME} /home/${BACKUP_USER_NAME}/persist/\"\${BACKUP_NAME}.enc\"
sudo chmod 400 /home/${BACKUP_USER_NAME}/persist/\"\${BACKUP_NAME}.enc\"
"


RESTORE_SCRIPT_CONTENT="
#!/bin/bash

echo \"[INFO] restoring backup ...\"

ENC_BACKUP_NAME=\$(sudo bash -c \"find /home/${BACKUP_USER_NAME}/restore/${BACKUP_FILE_PREFIX}-backup-*.tar.gz.enc\")
ENC_BACKUP_NAME=\"\$(basename \$ENC_BACKUP_NAME)\"

BACKUP_NAME=\"\${ENC_BACKUP_NAME::-4}\"


cd /home/${TAIGA_USER_NAME}/
sudo openssl aes-256-cbc -d -in /home/${BACKUP_USER_NAME}/restore/\${ENC_BACKUP_NAME} -out \${BACKUP_NAME} -kfile backup-key.txt


mkdir tmp
cd tmp/
tar -xzf ./../\${BACKUP_NAME}
cd ~


sudo mv tmp/home/${BACKUP_USER_NAME}/.ssh/authorized_keys /home/${BACKUP_USER_NAME}/.ssh/authorized_keys
sudo chown ${BACKUP_USER_NAME}:${BACKUP_USER_NAME} /home/${BACKUP_USER_NAME}/.ssh/authorized_keys


rm -rf taiga-back/media
mv tmp/taiga-back/media taiga-back/media


sudo -u postgres dropdb taiga
sudo -u postgres createdb taiga
sudo -u postgres pg_restore -d taiga tmp/taiga.dump


rm -r tmp/
rm -f \${BACKUP_NAME}
sudo rm -f /home/${BACKUP_USER_NAME}/restore/\${ENC_BACKUP_NAME}


echo \"[INFO] rebooting ...\"
sudo reboot
"


ADD_BACKUP_SSHKEY_SCRIPT_CONTENT="
#!/bin/bash

PUB_SSH_KEY=\$1


if ! [ \${PUB_SSH_KEY:0:7} = \"ssh-rsa\" ]; then
    echo \"[ERROR] input parameter seems not to be an ssh-rsa public key\"
elif ! [ \$# = 1 ]; then
    echo \"[ERROR] two many arguments. Surround rsa key with double quotes: \\\"<PUBLIC KEY>\\\"\"
else
    echo \"command=\\\"if [[ \\\\\\\"\\\$SSH_ORIGINAL_COMMAND\\\\\\\" =~ ^scp[[:space:]]-t[[:space:]]restore/.? ]] || [[ \\\\\\\"\\\$SSH_ORIGINAL_COMMAND\\\\\\\" =~ ^scp[[:space:]]-f[[:space:]]persist/.? ]]; then \\\$SSH_ORIGINAL_COMMAND ; else echo Access Denied; fi\\\",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding \${PUB_SSH_KEY}\" | sudo tee -a /home/${BACKUP_USER_NAME}/.ssh/authorized_keys > /dev/null
fi
"


UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT="
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Download-Upgradeable-Packages \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"1\";
"


RENEW_CERTIFICATE_SCRIPT_CONTENT="
#!/bin/bash

echo \"[INFO] \$(date) ...\" > renew-certificate.log

echo \"[INFO] stopping nginx service ...\" >> renew-certificate.log
systemctl stop nginx.service >> renew-certificate.log
echo \"\" >> renew-certificate.log

echo \"[INFO] renewing certificate ...\" >> renew-certificate.log
certbot renew >> renew-certificate.log
echo \"\" >> renew-certificate.log

echo \"[INFO] restarting nginx service ...\" >> renew-certificate.log
systemctl start nginx.service >> renew-certificate.log
"


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] setting language variables to solve location problems ..."
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
sudo service nginx stop


echo "" && echo "[INFO] installing rabbitmq ..."
sudo apt install -y rabbitmq-server redis-server


echo "" && echo "[INFO] installing circus ..."
sudo apt install -y circus


echo "" && echo "[INFO] installing postgresql ..."
sudo apt install -y postgresql-9.5 postgresql-contrib-9.5
sudo apt install -y postgresql-doc-9.5 postgresql-server-dev-9.5


echo "" && echo "[INFO] installing python ..."
sudo apt install -y python3 python3-pip python-dev python3-dev python-pip virtualenvwrapper
sudo apt install -y libxml2-dev libxslt-dev
sudo apt install -y libssl-dev libffi-dev


if [ ${ENABLE_LETSENCRYPT} == true ]; then

    echo "" && echo "[INFO] installing Let's Encrypt certbot ..."
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:certbot/certbot
    sudo apt update -y
    sudo apt install -y certbot

fi


echo "" && echo "[INFO] configuring postgresql ..."
sudo -u postgres createuser ${TAIGA_USER_NAME}
sudo -u postgres createdb ${TAIGA_USER_NAME} -O ${TAIGA_USER_NAME} --encoding='utf-8' --locale=en_US.utf8 --template=template0


echo "" && echo "[INFO] configuring rabbitmq ..."
sudo rabbitmqctl add_user ${TAIGA_USER_NAME} ${TAIGA_EVENTS_PASSWORD}
sudo rabbitmqctl add_vhost ${TAIGA_USER_NAME}
sudo rabbitmqctl set_permissions -p ${TAIGA_USER_NAME} ${TAIGA_USER_NAME} ".*" ".*" ".*"


echo "" && echo "[INFO] creating log folder ./logs/ ..."
mkdir -p ~/logs


echo "[INFO] downloading taiga backend ..."
cd ~
git clone https://github.com/taigaio/taiga-back.git taiga-back
cd taiga-back
git checkout stable


echo "" && echo "[INFO] creating new virtualenv ..."
source /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh
mkvirtualenv -p /usr/bin/python3.5 taiga


echo "" && echo "[INFO] installing python dependencies ..."
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
echo "${TAIGA_BACKEND_CONFIG_FILE_CONTENT}" > ~/taiga-back/settings/local.py


echo "" && echo "[INFO] downloading taiga frontend ..."
cd ~
git clone https://github.com/taigaio/taiga-front-dist.git taiga-front-dist
cd taiga-front-dist
git checkout stable


echo "" && echo "[INFO] creating fontend configuration ..."
echo "${TAIGA_FRONTEND_CONFIG_FILE_CONTENT}" > ~/taiga-front-dist/dist/conf.json


echo "" && echo "[INFO] downloading taiga events ..."
cd ~
git clone https://github.com/taigaio/taiga-events.git taiga-events
cd taiga-events


echo "" && echo "[INFO] installing nodejs ..."
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
sudo apt-get install -y nodejs


echo "" && echo "[INFO] installing coffee-script ..."
npm install
sudo npm install -g coffee-script


if [ ${ENABLE_LETSENCRYPT} == true ]; then

    echo "" && echo "[INFO] requesting Let's Encrypt certificate ..."
    sudo certbot certonly -n --standalone --agree-tos --register-unsafely-without-email -d ${SERVER_DOMAIN} --rsa-key-size 4096

  
    echo "" && echo "[INFO] creating links to certificate and key and setting permissions ..."
    sudo mkdir -p /etc/nginx/ssl
    sudo ln -s /etc/letsencrypt/live/${SERVER_DOMAIN}/fullchain.pem /etc/nginx/ssl/cert.pem
    sudo ln -s /etc/letsencrypt/live/${SERVER_DOMAIN}/privkey.pem /etc/nginx/ssl/key.pem

    sudo chown root:${TAIGA_USER_NAME} /etc/letsencrypt/live
    sudo chmod 750 /etc/letsencrypt/live

    sudo chown root:${TAIGA_USER_NAME} /etc/letsencrypt/archive
    sudo chmod 750 /etc/letsencrypt/archive


    echo "" && echo "[INFO] creating renew certificate job"
    echo "${RENEW_CERTIFICATE_SCRIPT_CONTENT}" > /home/${TAIGA_USER_NAME}/renew-certificate.sh
    sudo chmod 700 /home/${TAIGA_USER_NAME}/renew-certificate.sh
    (sudo crontab -l 2>> /dev/null; echo "${LETSENCRYPT_RENEW_EVENT}	/bin/bash /home/${TAIGA_USER_NAME}/renew-certificate.sh") | sudo crontab -

else

    echo "" && echo "[INFO] creating self signed certificate ..."
    openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=${SERVER_DOMAIN}"
    sudo mkdir -p /etc/nginx/ssl
    sudo mv cert.pem /etc/nginx/ssl/
    sudo mv key.pem /etc/nginx/ssl/

fi

if [ ${RECREATING_DH_PARAMETER} == true ]; then
    echo "" && echo "[INFO] recreating diffie hellman parameter ..."
    cd /etc/ssl
    sudo openssl dhparam -out dhparam.pem 4096
fi


echo "" && echo "[INFO] creating events configuration ..."
echo "${TAIGA_EVENTS_CONFIG_FILE_CONTENT}" > ~/taiga-events/config.json


echo "" && echo "[INFO] creating circus configurations ..."
echo "${CIRCUS_TAIGA_EVENTS_CONFIG_FILE_CONTENT}" | sudo tee /etc/circus/conf.d/taiga-events.ini > /dev/null
echo "${CIRCUS_TAIGA_BACKEND_CONFIG_FILE_CONTENT}" | sudo tee /etc/circus/conf.d/taiga.ini > /dev/null
echo "${CIRCUS_TAIGA_CELERY_CONFIG_FILE_CONTENT}" | sudo tee /etc/circus/conf.d/taiga-celery.ini > /dev/null


echo "" && echo "[INFO] creating nginx configuration ..."
sudo rm /etc/nginx/sites-enabled/default
echo "${NGINX_CONFIGURATION_FILE_CONTENT}" | sudo tee /etc/nginx/conf.d/taiga.conf > /dev/null
sudo nginx -t


echo "" && echo "[INFO] enabling unattended-upgrade ..."
echo "${UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT}" | sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null


echo "" && echo "[INFO] creating taiga backup user ..."
cd ~
sudo adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Taiga Backup Account' \
   --group \
   --disabled-password \
   --home /home/${BACKUP_USER_NAME} \
   ${BACKUP_USER_NAME}

sudo mkdir -p /home/${BACKUP_USER_NAME}/persist
sudo mkdir -p /home/${BACKUP_USER_NAME}/restore

sudo chown ${BACKUP_USER_NAME}:${BACKUP_USER_NAME} /home/${BACKUP_USER_NAME}/persist
sudo chown ${BACKUP_USER_NAME}:${BACKUP_USER_NAME} /home/${BACKUP_USER_NAME}/restore

sudo chmod 500 /home/${BACKUP_USER_NAME}/persist
sudo chmod 300 /home/${BACKUP_USER_NAME}/restore
sudo chmod 700 /home/${BACKUP_USER_NAME}


echo "" && echo "[INFO] creating files for ssh public keys for ${BACKUP_USER_NAME} ..."
sudo mkdir -p /home/${BACKUP_USER_NAME}/.ssh
echo "" | sudo tee /home/${BACKUP_USER_NAME}/.ssh/authorized_keys > /dev/null

sudo chown ${BACKUP_USER_NAME}:${BACKUP_USER_NAME} /home/${BACKUP_USER_NAME}/.ssh
sudo chown ${BACKUP_USER_NAME}:${BACKUP_USER_NAME} /home/${BACKUP_USER_NAME}/.ssh/authorized_keys

sudo chmod 700 /home/${BACKUP_USER_NAME}/.ssh
sudo chmod 400 /home/${BACKUP_USER_NAME}/.ssh/authorized_keys


echo "" && echo "[INFO] storing backup key ..."
echo ${BACKUP_KEY} > backup-key.txt
chmod 600 backup-key.txt


echo "" && echo "[INFO] creating backup job ..."
echo "${BACKUP_SCRIPT_CONTENT}" > /home/${TAIGA_USER_NAME}/create-backup.sh
chmod 700 /home/${TAIGA_USER_NAME}/create-backup.sh
(sudo crontab -l 2> /dev/null; echo "${BACKUP_EVENT}	/bin/bash /home/${TAIGA_USER_NAME}/create-backup.sh") | sudo crontab -


echo "" && echo "[INFO] creating backup ssh key script ..."
echo "${ADD_BACKUP_SSHKEY_SCRIPT_CONTENT}" > /home/${TAIGA_USER_NAME}/add-backup-ssh-key.sh
chmod 700 /home/${TAIGA_USER_NAME}/add-backup-ssh-key.sh


echo "" && echo "[INFO] creating backup restore script ..."
echo "${RESTORE_SCRIPT_CONTENT}" > /home/${TAIGA_USER_NAME}/restore-backup.sh
chmod 700 /home/${TAIGA_USER_NAME}/restore-backup.sh


if [ ${ENABLE_CYCLIC_REBOOT} == true ]; then

    echo "" && echo "[INFO] creating reboot job ..."
    (sudo crontab -l 2> /dev/null; echo "${CYCLIC_REBOOT_EVENT}	/sbin/reboot") | sudo crontab -

fi


echo "" && echo "[INFO] cleaning up ..."
sudo apt autoremove -y


echo "" && echo "[INFO] installation finished. Rebooting ..."
sudo reboot