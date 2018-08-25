#!/bin/sh


#==================================================================

SERVER_ADDRESS="taiga.some.one"
PASSWORD_FOR_EVERYTHING="Taigaio"
SECRET_KEY="theverysecretkey"

#==================================================================


function apt-install {
    for package in $@; do
        echo "[APT-GET] Installing package $package..."
        sudo apt-get install -y -qq $package
    done
}
 
cd ~
sudo -v
sudo chown -R taiga /home/taiga

echo "[INFO] Updating system..."
sudo apt-get -y -qq update
sudo apt-get -y -qq upgrade
sudo apt-get -y -qq dist-upgrade

echo "[INFO] Installing essential packages..."
apt-install build-essential binutils-doc autoconf flex bison libjpeg-dev
apt-install libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev
apt-install automake libtool libffi-dev curl git tmux gettext
apt-install nginx
apt-install rabbitmq-server redis-server
apt-install circus
apt-install postgresql-9.5 postgresql-contrib-9.5
apt-install postgresql-doc-9.5 postgresql-server-dev-9.5

echo "[INFO] Installing Python 3..."
apt-install python3 python3-pip python-dev python3-dev python-pip
apt-install libxml2-dev libxslt-dev
apt-install libssl-dev libffi-dev
cd ~
cat > .bashrc <<EOF
alias python=python3
alias pip=pip3
EOF
source ~/.bashrc

echo "[INFO] Configuring postgresql..."
sudo -u postgres createuser taiga
sudo -u postgres createdb taiga -O taiga --encoding='utf-8' --locale=en_US.utf8 --template=template0

echo "[INFO] Configuring RabbitMQ..."
sudo rabbitmqctl add_user taiga $PASSWORD_FOR_EVERYTHING
sudo rabbitmqctl add_vhost taiga
sudo rabbitmqctl set_permissions -p taiga taiga ".*" ".*" ".*"
echo "[INFO] Creating the logs folder"
mkdir -p ~/logs

echo "[INFO] Downloading Taiga Backend..."
cd ~
git clone https://github.com/taigaio/taiga-back.git taiga-back
cd taiga-back
git checkout stable


echo "[INFO] Installing Python dependencies..."
pip install -r requirements.txt

echo "[INFO] Populating the database with basic data..."
python manage.py migrate --noinput
python manage.py loaddata initial_user
python manage.py loaddata initial_project_templates
python manage.py compilemessages
python manage.py collectstatic --noinput

echo "[INFO] Configuring Taiga Backend..."
cat > settings/local.py <<EOF
from .common import *

MEDIA_URL = "http://$SERVER_ADDRESS/media/"
STATIC_URL = "http://$SERVER_ADDRESS/static/"
SITES["front"]["scheme"] = "http"
SITES["front"]["domain"] = "$SERVER_ADDRESS"

SECRET_KEY = "$SECRET_KEY"

DEBUG = False
PUBLIC_REGISTER_ENABLED = True

DEFAULT_FROM_EMAIL = "no-reply@$SERVER_ADDRESS"
SERVER_EMAIL = DEFAULT_FROM_EMAIL

#CELERY_ENABLED = True

EVENTS_PUSH_BACKEND = "taiga.events.backends.rabbitmq.EventsPushBackend"
EVENTS_PUSH_BACKEND_OPTIONS = {"url": "amqp://taiga:$PASSWORD_FOR_EVERYTHING@localhost:5672/taiga"}

# Uncomment and populate with proper connection parameters
# for enable email sending. EMAIL_HOST_USER should end by @domain.tld
#EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
#EMAIL_USE_TLS = False
#EMAIL_HOST = "localhost"
#EMAIL_HOST_USER = ""
#EMAIL_HOST_PASSWORD = ""
#EMAIL_PORT = 25

# Uncomment and populate with proper connection parameters
# for enable github login/singin.
#GITHUB_API_CLIENT_ID = "yourgithubclientid"
#GITHUB_API_CLIENT_SECRET = "yourgithubclientsecret"
EOF

echo "[INFO] Downloading Taiga Frontend..."
cd ~
git clone https://github.com/taigaio/taiga-front-dist.git taiga-front-dist
cd taiga-front-dist
git checkout stable

echo "[INFO] Configuring Taiga Frontend..."
cat > ~/taiga-front-dist/dist/conf.json <<EOF
{
    "api": "http://$SERVER_ADDRESS/api/v1/",
    "eventsUrl": "ws://$SERVER_ADDRESS/events",
    "debug": "true",
    "publicRegisterEnabled": true,
    "feedbackEnabled": true,
    "privacyPolicyUrl": null,
    "termsOfServiceUrl": null,
    "GDPRUrl": null,
    "maxUploadFileSize": null,
    "contribPlugins": []
}
EOF

echo "[INFO] Downloading Taiga Events..."
cd ~
git clone https://github.com/taigaio/taiga-events.git taiga-events
cd taiga-events

echo "[INFO] Installing nodejs..."
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
apt-install nodejs

echo "[INFO] Installing coffe-script..."
npm install
sudo npm install -g coffee-script

echo "[INFO] Configuring Taiga Events..."
cp config.example.json config.json
cat > conf.json <<EOF
{
    "url": "amqp://taiga:$PASSWORD_FOR_EVERYTHING@$SERVER_ADDRESS:5672/taiga",
    "secret": "$SECRET_KEY",
    "webSocketServer": {
        "port": 8888
    }
}
EOF
cat > /etc/circus/conf.d/taiga-events.ini <<EOF
[watcher:taiga-events]
working_dir = /home/taiga/taiga-events
cmd = /usr/bin/coffee
args = index.coffee
uid = taiga
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/taiga/logs/taigaevents.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 12
stderr_stream.class = FileStream
stderr_stream.filename = /home/taiga/logs/taigaevents.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 12
EOF

echo "[INFO] Configuring circus..."
cat > /etc/circus/conf.d/taiga.ini <<EOF
[watcher:taiga]
working_dir = /home/taiga/taiga-back
cmd = gunicorn
args = -w 3 -t 60 --pythonpath=. -b 127.0.0.1:8001 taiga.wsgi
uid = taiga
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/taiga/logs/gunicorn.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 4
stderr_stream.class = FileStream
stderr_stream.filename = /home/taiga/logs/gunicorn.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 4

[env:taiga]
PATH = /usr/bin/python3.5:\$PATH
TERM=rxvt-256color
SHELL=/bin/bash
USER=taiga
LANG=en_US.UTF-8
HOME=/home/taiga
PYTHONPATH=/usr/lib/python3.5/site-packages
EOF
sudo service circusd restart

echo "[INFO] Configuring Nginx..."
sudo rm /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/taiga.conf <<EOF
server {
    listen 80 default_server;
    server_name $SERVER_ADDRESS;

    large_client_header_buffers 4 32k;
    client_max_body_size 50M;
    charset utf-8;

    access_log /home/taiga/logs/nginx.access.log;
    error_log /home/taiga/logs/nginx.error.log;

    # Frontend
    location / {
        root /home/taiga/taiga-front-dist/dist/;
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
        alias /home/taiga/taiga-back/static;
    }

    # Media files
    location /media {
        alias /home/taiga/taiga-back/media;
    }

    # Taiga-events
    location /events {
        proxy_pass http://127.0.0.1:8888/events;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
EOF
sudo service circusd restart
sudo service nginx restart

echo "[INFO] Configuring HTTPS..."
cd ~
curl --silent https://raw.githubusercontent.com/srvrco/getssl/master/getssl > getssl ; chmod 700 getssl
sudo ./getssl -c $SERVER_ADDRESS
cat > ~/.getssl/$SERVER_ADDRESS/getssl.cfg <<EOF
# Uncomment and modify any variables you need
# see https://github.com/srvrco/getssl/wiki/Config-variables for details
# see https://github.com/srvrco/getssl/wiki/Example-config-files for example configs
#
# The staging server is best for testing
#CA="https://acme-staging.api.letsencrypt.org"
# This server issues full certificates, however has rate limits
CA="https://acme-v01.api.letsencrypt.org"

PRIVATE_KEY_ALG="rsa"

# Additional domains - this could be multiple domains / subdomains in a comma separated list
SANS="www.$SERVER_ADDRESS"

# Acme Challenge Location. The first line for the domain, the following ones for each additional domain.
# If these start with ssh: then the next variable is assumed to be the hostname and the rest the location.
# An ssh key will be needed to provide you with access to the remote server.
# Optionally, you can specify a different userid for ssh/scp to use on the remote server before the @ sign.
# If left blank, the username on the local server will be used to authenticate against the remote server.
# If these start with ftp: then the next variables are ftpuserid:ftppassword:servername:ACL_location
# These should be of the form "/path/to/your/website/folder/.well-known/acme-challenge"
# where "/path/to/your/website/folder/" is the path, on your web server, to the web root for your domain.
ACL=('/home/taiga/taiga-front-dist/dist/.well-known/acme-challenge'
     '/home/taiga/taiga-front-dist/dist/.well-known/acme-challenge')

# Location for all your certs, these can either be on the server (so full path name) or using ssh as for the ACL
DOMAIN_CERT_LOCATION="/etc/nginx/ssl/$SERVER_ADDRESS.crt"
DOMAIN_KEY_LOCATION="/etc/nginx/ssl/$SERVER_ADDRESS.key"
CA_CERT_LOCATION="/etc/nginx/ssl/chain.crt"
#DOMAIN_CHAIN_LOCATION="" this is the domain cert and CA cert
#DOMAIN_PEM_LOCATION="" this is the domain_key. domain cert and CA cert


# The command needed to reload apache / nginx or whatever you use
RELOAD_CMD="sudo sevice nginx reload"

# Define the server type. This can be https, ftp, ftpi, imap, imaps, pop3, pop3s, smtp,
# smtps_deprecated, smtps, smtp_submission, xmpp, xmpps, ldaps or a port number which
# will be checked for certificate expiry and also will be checked after
# an update to confirm correct certificate is running (if CHECK_REMOTE) is set to true
SERVER_TYPE="https"
CHECK_REMOTE="true"
EOF
sudo ./getssl $SERVER_ADDRESS
cd /etc/ssl
sudo openssl dhparam -out dhparam.pem 2048
cat > /etc/nginx/conf.d/taiga.conf <<EOF
server {
    listen 80 default_server;
    server_name $SERVER_ADDRESS;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl default_server;
    server_name $SERVER_ADDRESS;

    large_client_header_buffers 4 32k;
    client_max_body_size 50M;
    charset utf-8;

    index index.html;

    # Frontend
    location / {
        root /home/taiga/taiga-front-dist/dist/;
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
        alias /home/taiga/taiga-back/static;
    }

    # Media files
    location /media {
        alias /home/taiga/taiga-back/media;
    }

    # Taiga-events
    location /events {
        proxy_pass http://127.0.0.1:8888/events;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header Public-Key-Pins 'pin-sha256="klO23nT2ehFDXCfx3eHTDRESMz3asj1muO+4aIdjiuY="; pin-sha256="633lt352PKRXbOwf4xSEa1M517scpD3l5f79xMD9r9Q="; max-age=2592000; includeSubDomains';

    ssl on;
    ssl_certificate /etc/nginx/ssl/$SERVER_ADDRESS.crt;
    ssl_certificate_key /etc/nginx/ssl/$SERVER_ADDRESS.key;
    ssl_session_timeout 5m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK';
    ssl_session_cache shared:SSL:10m;
    ssl_dhparam /etc/ssl/dhparam.pem;
    ssl_stapling on;
    ssl_stapling_verify on;

}
EOF
cat > ~/taiga-back/settings/local.py <<EOF
from .common import *

MEDIA_URL = "https://$SERVER_ADDRESS/media/"
STATIC_URL = "https://$SERVER_ADDRESS/static/"
SITES["front"]["scheme"] = "https"
SITES["front"]["domain"] = "$SERVER_ADDRESS"

SECRET_KEY = "$SECRET_KEY"

DEBUG = False
PUBLIC_REGISTER_ENABLED = True

DEFAULT_FROM_EMAIL = "no-reply@$SERVER_ADDRESS"
SERVER_EMAIL = DEFAULT_FROM_EMAIL

#CELERY_ENABLED = True

EVENTS_PUSH_BACKEND = "taiga.events.backends.rabbitmq.EventsPushBackend"
EVENTS_PUSH_BACKEND_OPTIONS = {"url": "amqp://taiga:$PASSWORD_FOR_EVERYTHING@localhost:5672/taiga"}

# Uncomment and populate with proper connection parameters
# for enable email sending. EMAIL_HOST_USER should end by @domain.tld
#EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
#EMAIL_USE_TLS = False
#EMAIL_HOST = "localhost"
#EMAIL_HOST_USER = ""
#EMAIL_HOST_PASSWORD = ""
#EMAIL_PORT = 25

# Uncomment and populate with proper connection parameters
# for enable github login/singin.
#GITHUB_API_CLIENT_ID = "yourgithubclientid"
#GITHUB_API_CLIENT_SECRET = "yourgithubclientsecret"
EOF
cat > ~/taiga-front-dist/dist/conf.json <<EOF
{
    "api": "https://$SERVER_ADDRESS/api/v1/",
    "eventsUrl": "wss://$SERVER_ADDRESS/events",
    "debug": "true",
    "publicRegisterEnabled": true,
    "feedbackEnabled": true,
    "privacyPolicyUrl": null,
    "termsOfServiceUrl": null,
    "GDPRUrl": null,
    "maxUploadFileSize": null,
    "contribPlugins": []
}
EOF
sudo service circusd restart
sudo service nginx restart
circusctl stop taiga
circusctl start taiga

echo "[INFO] Setting up automated updating..."
cat > ~/Update.sh <<EOF
cd ~/taiga-front-dist
git checkout stable
git pull
cd ~/taiga-back
git checkout stable
git pull
pip install --upgrade -r requirements.txt
python manage.py migrate --noinput
python manage.py compilemessages
python manage.py collectstatic --noinput
circusctl reload taiga
EOF
crontab -l > ~/cronfile.txt
cat >> ~/cronfile.txt <<EOF
0 0 * * * sudo bash ~/Update.sh
EOF
sudo crontab ~/cronfile.txt
sudo rm cronfile.txt

echo "[INFO] Checking if everything works..."
sudo service rabbitmq-server status
sudo service postgresql status
sudo service nginx status
sudo nginx -t
sudo service circusd status
circusctl status