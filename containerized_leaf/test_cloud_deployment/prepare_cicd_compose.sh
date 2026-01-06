#!/bin/bash

## before running this file, update your .env file with a unique password an appropriate JWT URL

FILE_PATH="master.zip"
KEY_PATH="keys/cert.pem"

## Grab latest version of Leaf from the github repository
if [ -e "$FILE_PATH" ]; then
  echo "$FILE_PATH exists."
else
  echo "$FILE_PATH does not exist."
    ## get zip file 
  wget https://github.com/uwrit/leaf/archive/refs/heads/master.zip

    ## unzip file
  unzip master.zip
fi

## create a key pair if one doesn't exist. Simply delete the keys in the 'keys' folder
if [ -e "$KEY_PATH" ]; then
  echo "$KEY_PATH exists."
else
    ## load .env
  source ./api_server/.env_cicd

    ## create JWT keys
  mkdir certs
  mkdir keys

  openssl req -nodes -x509 -newkey rsa:2048 -keyout keys/key.pem -out keys/cert.pem -days 3650 -subj "/CN=urn:leaf:issuer:$LEAF_JWT_URL"
  openssl pkcs12 -in keys/cert.pem -inkey keys/key.pem -export -out keys/leaf.pfx -password pass:$LEAF_JWT_KEY_PW

fi


## add entrypoints and Dockerfiles to existing Leaf folders.
## api server uses custom docker file
cp -f api_server/api_Dockerfile leaf-master/src/server/api_Dockerfile
cp -f api_server/entrypoint.sh leaf-master/src/server/entrypoint.sh
cp -f api_server/appsettings.json leaf-master/src/server/appsettings.json
cp -f keys/* leaf-master/src/server/
chmod +x leaf-master/src/server/entrypoint.sh

## web server
cp -f web_server/* leaf-master/src/ui-client/

