# taiga-server

## Requirements
Fresh Ubuntu 16.04 x64

## Scripts
These scripts set up Taiga with HTTPS. They also create an administrator `admin` withe the password `123123`

## Server Installation
1. create a new user with the name `taiga` and login as `taiga`
2. give that user sudo permissions
3. copy all files from the `scripts` directory to `/home/taiga`
4. change `SERVER_ADDRESS` and `PASSWORD_FOR_EVERYTHING` in every file according to your needs
5. execute `bash ./Taigaio.sh`