# taiga-server
repository for taiga server hosting

## Requirements
Fresh Ubuntu 16.04 x64

## Scripts
This script sets up Taiga with HTTPS. It also creates an administrator `admin` with the password `123123`

## Server Installation
1. create a new user with the name `taiga` and give that user sudo permissions
2. login as `taiga`
3. copy the script to `/home/taiga`
4. change `SERVER_ADDRESS` and `PASSWORD_FOR_EVERYTHING` in the script according to your needs
5. execute `bash ./Taigaio.sh`