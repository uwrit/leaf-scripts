
If you are deploying Leaf in a containerized environment you will likely want to run it from a github or gitlab environment supporting CI/CD that then refreshes the environment accordingly.

With this CICD driven workflow we're using utilizing the following elements using gitlab driven workflow:

- Repository Variables - for storing JWT password and connection strings
- A CI/CD action definition - .gitlab-ci.yml / .workflows/leaf_build.yml
- A gitlab/github runner, setup as a shell executor, who is a member of the docker group
- gitlab/github Environments


## CI/CD Deployment Setup

The process described below is for a non-prod deployment.  See the ```production_cloud_deployment``` folder to review additional steps neded for setup of SSO with a "Production" deployment of Leaf.

This deployment assumes you are only deploying an API container and a Web Front End container via Apache. This deployment assumes an outside database server. If you do want to deploy a cloud SQL server instance via docker compose you will want refer to the docker-compose block in the ```local_development``` folder. You will want to customize that container deployment to match the api container method for storing your service account password described below.


## Set the Repository Variables

First we'll need to first create CI/CD variables in our repository. These are our 'password' variables that define our database connections. 

- Github: Settings --> Secrets & Variables --> Actions --> Secrets. (Or if using separate environments in your repository, go to Settings --> Environments --> [choose your environment])
- Gitlab: Settings --> CI/CD --> Variables.

Make sure to attach the variable to the right environment if using separate environments. (Defining an environment in your ci file is enough to ensure it exists.)

**Don't put double quotes around your strings.**

- LEAF_JWT_KEY_PW  - this should be a simple alpha neumeric password ```dadfawewD553afe ```
- LEAF_APP_DB  - ```Server=leaf_sqlserver_db,1433;Database=LeafDB;uid=leaf_service_account;Password=Th3PA55--8zz   ```
- LEAF_CLIN_DB - ```Server=leaf_sqlserver_db,1433;Database=ClinicalWarehouse;uid=leaf_service_account;Password=Th3PA55--8zz   ```

The application database is only for Leaf Operational needs.  The clinical database is where the actual clinical data lives, likely in OMOP or PCORNET formats.

Reference: https://leafdocs.rit.uw.edu/installation/installation_steps/7_env/ 



## Customize your CI/CD workflow

Below describes the bare bones of deploying the containers with a local runner, either a Github Actions Runner or a Gitlab CI runner.

The provided example actions for both gitlab and github do a full rebuild of the environment every time. These actions are by default manual actions meant to be triggered from the github/gitlab UI.

### GitHub actions

Actions live in the ```.workflow/``` folder.  There is just one action build_leaf.

Ensure your local-runner has the right tags attached so the job will run. You shouldn't need to adjust the action unless you need to:
- specify a different environment to deploy to
- specify a different tag to trigger off of


### Gitlab CI
Our example contains a ```.gitlab-ci.yml``` file which has an example workflow for refreshing containers using a gitlab runner. But we should customize a few things before this can be used.

1. Attach your appropriate runner to the repository. Ensure it has the unique tags you want to use with the repository attached and can run docker containers.
2. Update the .gitlab-ci.yml tags to match the tag you just set for the runner.
  - If you are only running the API container remove the lines for the ui-client in each job.
  - If you are setting up multiple environments, add appropriate environment tag to trigger here. (Or remove the environment tag if you aren't using environments.)
3. Update the api_server/.env_cicd with an appropriate URL. (optional)

References:
- https://docs.gitlab.com/runner/
- https://docs.gitlab.com/ci/
- https://docs.gitlab.com/ci/variables/
- https://docs.gitlab.com/ci/docker/using_docker_build/


## Customize your Application Definition
Depending on how you are deploying this application you may wish to customize a URL or update your docker compose file.

### Customize Apache Web Front End Container
If hosting a dev or test site:
- Set Apache to limit by IP address range

1. Customize apache_reverse_proxy/httpd_leaf.conf
  - Customize URL 
  - Customize access model - set IP address ranges

Reference: https://leafdocs.rit.uw.edu/installation/installation_steps/8a_configure_apache/ 


### Confirm your Docker compose file

Take a look at your apionly-conmpose.yml file:
  - If you are only running the API container remove the block for the leaf_web
  - customize your port mapping to be appropriate for apache setup you just customized
  - if you are managing multiple environments on the same docker server, rename the service and container_name to include the environment.  eg.  leaf_web_tst. You will need to update your gitlab-ci docker commands to reference the updated names as well. 



## Do an Environment Initialization or Rebuild

By default the actions are set to be manual only so they need to manually triggered in the CI/CD jobs interface.

In Gitlab: Go to Build --> Jobs. Find you latest commit and hit the play button and then run the 'build_leaf' job. 

In Github: Go to Actions. Manually trigger the 'build_leaf' action.

This will have the runner build a fresh environment for you.

This downloads a fresh install of Leaf and then injects our customized configuration files for our docker build.

This then builds the docker containers and runs them.


