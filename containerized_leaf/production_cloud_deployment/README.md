This document assumes you are building a standalone web-facing container with SSO functionality built in using the Apache + Shibboleth SAML integration.

This deployment is a variation on the ```test_cloud_deployment``` where we take additional setup to enable Single Sign-On with SAML:
  - Compile and Build Shibboleth into a stock apache container
  - Provide customized Baseline Apache configuration enabling all needed modules that are not enabled by default
  - Deploy with SSL Certificates Setup
  - Enable SAML SSO with Shibboleth

The SSO setup process is also covered at the leafdocs site: https://leafdocs.rit.uw.edu/installation/installation_steps/9_saml2/


# Production Leaf


If you are deploying Leaf in a containerized environment you will likely want to run it from a github or gitlab environment supporting CI/CD that then refreshes the environment accordingly.

With this CICD driven workflow we're using utilizing the following elements using gitlab driven workflow:
- Repository Variables - for storing JWT password and connection strings
- A CI/CD action definition - .gitlab-ci.yml
- A gitlab runner, setup as a shell executor, who is a member of the docker group
- gitlab Environments



## CI/CD Deployment Setup

This deployment assumes you are only deploying an API container and a Web Front End container via Apache. This deployment assumes an outside database server. If you do want to deploy a cloud SQL server instance via docker compose you will want refer to the docker-compose block in the ```local_development``` folder. You will want to customize that container deployment to match the api container method for storing your service account password described below.


## Set the Repository Variables

First we'll need to first create CI/CD variables in our repository. These are our 'password' variables that define our database connections. 

- Github: 
- Gitlab: Settings --> CI/CD --> Variables.

Make sure to attach the variable to the right environment if using separate environments. 

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
In a production setting you must take some additional steps to enable SSO.

- Creating SSL Certificates and Matching DNS entries
- Creating a SAML provider that will authenticate the application
- Customizing Shibboleth to reference the SAML provider you setup


### Create SSL Certificates

Create a top level folder called ```certs```. Place your SSL Certificates in this certs folder. 

Note: Placing the certs in a folder in a repository carries risk so should only be done on private repositories.  For a production workflow, best practice is to store certificate contents in a repository variable. That customization isn't in scope currently for this version 1 baseline container approach, however we intend to add it in the future.


### Customize Apache Web Front End Container
Enabling SSO for a production instance means the instance must have an associated SSL certificate referenced by apache and Shibboleth.

1. Customize web_server/shib_leaf.conf:
  - Customize URL 
  - Ensure SSL certificate name references are correct.  

Reference: https://leafdocs.rit.uw.edu/installation/installation_steps/8a_configure_apache/ 


### Setup Shibboleth

When customizing shibboleth configuration in shibboleth2.xml you will be doing two things:
- Setting the applicaiton URL (replacing 'leaf.example.net' with your URL)
- Setting the SAML provider details

When setting SAML provider details there are two blocks.

The first block defines the "entityid" and kind of SSO in use. 

```xml
            <SSO id="azure" isDefault="true" entityID="https://sts.windows.net/xxxxexamplexxxx/">
                SAML2
            </SSO>
```

The second block defines the metadata provider:

```xml
        <MetadataProvider type="XML" validate="true"
                url="https://login.microsoftonline.com/xxxxxxexamplexxxxx"
            backingFilePath="federation-metadata.xml" maxRefreshDelay="7200">
        </MetadataProvider>

```

In each of the above example cases we are using an Azure SAML endpoint. Details about setting up an Azure SAML endpoint in Azure for your leaf instance is available here:
https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/add-application-portal-setup-sso


### Update appsettings.json

The provided api_server/appsettings.json should just need a couple of changes to ensure it works with SAML SSO.

To enable role-based access you'll need to update the "Authorization" block with appropriate group names for your organization:

```yml
   "Authorization": {
    "Mechanism": "SAML2",
    "SAML2": {
      "HeadersMapping": {
        "Entitlements": {
          "Name": "gws_groups",
          "Delimiter": ";"
        }
      },
      "RolesMapping": {
        "User": "urn:mace:washington.edu:groups:uw_rit_leaf_demo_users",
        "Super": "urn:mace:washington.edu:groups:uw_rit_leaf_demo_supers",
        "Identified": "urn:mace:washington.edu:groups:uw_rit_leaf_demo_identified",
        "Admin": "urn:mace:washington.edu:groups:uw_rit_leaf_demo_admins",
        "Federated": "urn:mace:washington.edu:groups:uw_rit_leaf_demo_federated"
      }
    }
  },
```

For further details see:  https://leafdocs.rit.uw.edu/installation/installation_steps/9_saml2/ 


### Confirm your Docker compose file

Take a look at your apionly-compose.yml file:
  - If you are only running the API container remove the block for the leaf_web
  - customize your port mapping to be appropriate for apache setup you just customized


## Do an Environment Initialization or Rebuild

By default the actions are set to be manual only so they need to manually triggered in the CI/CD jobs interface.

In Gitlab: Go to Build --> Jobs. Find you latest commit and hit the play button and then run the 'build_leaf' job. 

In Github: Go to Actions. Manually trigger the 'build_leaf' action.

This will have the runner build a fresh environment for you.

This downloads a fresh install of Leaf and then injects our customized configuration files for our docker build.

This then builds the docker containers and runs them.


