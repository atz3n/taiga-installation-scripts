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
sudo pip3 install virtualenvwrapper
sudo pip install virtualenvwrapper
cd ~
cat > .bashrc <<EOF
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/Devel
source /usr/local/bin/virtualenvwrapper.sh
EOF
source ~/.bashrc
mkvirtualenv -p /usr/bin/python3.5 taiga

echo -e "[INFO] To Continue the Installation, please execute the following commands:\nbash\nworkon taiga\nsudo bash ./Taigaio2.sh"