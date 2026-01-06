# Containerized Leaf - For Local Development

Leaf is a project of UW Medicine Research IT and ITHS.
https://github.com/uwrit/leaf/tree/master


This repository is a standalone repository for containerizing the Leaf application easily for local machine hosting. This 'local_development' folder provides a baseline three-tier or two-tier Leaf environment hosted in docker containers in which is suitable for doing development on a local machine. 

- A SQL Server database Container - Leaf Application Database requires SQL Server
- A .net Container hosting the Leaf API and running the Leaf Web Interface
- An apache + shibboleth container approach for consuming SSO authentication. Just apache for now which should be fine for development. - SHIBBOLETH PART IN DEVELOPMENT 11/2025

When doing local development of either the ui or the API itself the apache container is not needed. When you are ready to deploy a non-local version of Leaf you will need to update the api_Dockerfile to [compile the SSO-enabled version of Leaf](https://leafdocs.rit.uw.edu/installation/installation_steps/4_compile_api/). Simply remove the 'ui_client' block from the docker-compose.yml file if you don't want to use the apache container.

References:
- https://leafdocs.rit.uw.edu/
- https://github.com/uwrit/leaf/tree/master
- https://github.com/uwrit/leaf-scripts


## Containerized Leaf Quickstart

The default settings for the docker-compose.yml driven container build is push button. No settings need to be changed to setup a demo environment on your local Docker.

It automatically does the work for you:
- Sets sa password for SQL Server database container and uses that 'sa' password for database connections
- Set's up both a Leaf application database and a Leaf Clinical data database in that same SQL server container
- Initializes Leaf Application Database as an empty database ready to be built out

The 'prepare_compose.sh' script simply downloads the latest version of the Leaf files from the main Leaf repository and unpacks them. Then we build some JWT keys for API communication and shuffle around some files to make the API ready for compilation into a container.

From the very top level of the repository you can run this one_liner to startup a fresh Leaf environment on your local machine. 
```sh
./prepare_compose.sh && docker compose up -d
```

By default a fresh SQL Server container will be built along with a fresh API container. This will take 10 or so minutes to download and put all the pieces together.  

Once built you should now be able to visit the locally hosted leaf web interface at either:

http://127.0.0.1:3000/ - Node Run version version of the site for development and debugging
http://127.0.0.1:3001/ - Apache Container provided site pointing to api container (only if you have the paahe container. )


## Explained: Key Details For Setting Up a Blank Local Leaf Instance for Development

The leaf build process is a scripted process and provides places where you may wish to modify the default workflow to take some additional container initialization actions.

For Example:
- Setup custom 'sa' admin password
- Setup a service account on the SQL Server (example provided)
- Clinical database setup
  - Load additional data into the SQL server to populate a blank default clinical database
  - Repoint the connection string at a separate clinical database you'll be referencing

When making customizations any key changes should only need to be made in:
- database_server/entrypoint.sh
- database_server/db_.env
- api_server/.env
- api_server/appsettings.json (probably not here, but maybe)

Once you've made your updates to those files simply re-run the one-liner above to re-consitute the environment.


### Local Build General process

1. Clone this repository.

2. Update the included .env files with appropriate unique values (optional if in development). These are where your SQL server 'sa' password is defined.
  - database_server/db_.env - set a unique SA password.
  - api_server/.env
    - setting JWT password
    - setting your connection string for your app database - use a non-'sa' service account if you want or match SA password set in other .env file if in development. (Service account setup script customization where you'll setup this password is in step 3.)
    - setting your connection string for your clinical database - could be local to the sql server, could be on another server. If creating locally customize database_server/empty_clinical_db.sql with preferred matching database details. 
3. Adjust initial database population requirements from database_server/entrypoint.py
  - By default a blank instance of Leaf is setup automatically.
  - If setting up a service account uncomment that line. Update database_server/service_account.sql with service account password. (optional in development context)
  - If creating a blank second clinical database as well uncomment that line so database will be creatin. (convenient for local development and related to step 2 connection string)

4. Run repository preparation script:  ``` ./prepare_compose.sh ```
  - Downloads Leaf from the master repository and unzips it.
  - Moves the ui-client folder into "server" folder context since both will live on a single container
  - Creates JWT keys for the API to use using your .env file 
  - Copies Updated Dockerfiles and entrypoint container startup scripts for used with the new docker-compose.yml file.

5. Create database container with docker compose. From the top level of the repo where the docker-compose.yml lives:
  - To stand up the Database server container using docker-compose.yml file:  ``` docker compose up -d leaf_db ```
  - There is no image 'build' step as we are just using the vanilla sql server container.

6. Create api + web containers with docker compose. From the top level of the repo where the docker-compose.yml lives:
  - To build the API container fresh using docker-compose.yml file:  ``` docker compose build leaf_api ```
  - To stand up the API container using docker-compose.yml file:  ``` docker compose up -d leaf_api ```

At this point you should now be able to visit the leaf web interface at:

http://127.0.0.1:3000/



## Developer Notes

- The script ```prepare_compose.sh``` downloads a copy of the leaf application zip and expands it into a folder called ```leaf-master```. This is where you will work on your customizations for either the API (in the ```leaf-master/src/server/``` folder) or the UI (in the ```leaf-master/src/ui-client/``` folder). 

- ```prepare_compose.sh``` checks for an already existing ```master.zip``` file and doesn't overwrite if one already exists. Leave the existing master.zip in place once you've begun developing.

- If you are working in a forked leaf repository for development you will need to do some additional updates to ensure the files from this repository aren't committed back to the fork. you will need to customize ```prepare_compose.sh``` in the following ways: 
  - Remove leaf download and folder expansion logic. 
  - Add the following block to your forked repository in ```.gitignore``` to ignore the injected files from this repository by ```prepare_compose.sh ```:
 ```sh 
./src/db/build/entrypoint.sh
./src/db/build/LeafDB.ServiceAccount.sql
./src/db/build/LeafDB.EmptyLocalClinicalDB.sql
./src/ui-client/httpd_leaf.conf
./src/ui-client/web_Dockerfile
./src/server/appsettings.json
./src/server/entrypoint.sh
./src/server/api_Dockerfile
./src/server/.env
./src/server/ui-client/
```
  - You will need to update prepare_compose to copy deployment files into the forked repository instead of the locally downloaded ```leaf-master``` folder.

- As the context here is a development instance of Leaf, api_server/entrypoint.sh refers to the version of the API that is being compiled at container build time. The Leaf repository also comes with a pre-packaged version of Leaf that can be started at /app/API/ instead of /var/opt/leafapi/api/API/.

- The apache container definition is more of a convenience and is not strictly necessary for doing local development. The Apache + Shibboleth integration is used primarily for properly consuming SAML tokens in the production deployment where SSO is involved. 

