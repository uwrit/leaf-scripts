This folder provides three example Leaf deployments using Docker Compose to build a 3-tier containerized Leaf environment:  Web --> App --> Database. (See https://leafdocs.rit.uw.edu/installation/ for more details on architecture choices.)

The three different types of environments are:
- A full local environment built with Docker Compose suitable for doing Leaf Development, including a local SQL Server
- A non-prod deployment built with Docker Compose, without SSO enabled
- A production deployment built with Docker Compose, with SSO enabled

The non-prod and production deployments are built assuming you are deploying Leaf to a local Docker instance using cloud tools:
- Either Github or Gitlab as your code management tool
- Using a local runner (gitlab or github) on a server with Docker installed where the runner account is a member of the 'docker' group (so can manage containers)
- Using a separate database server:
  - A SQL Server for hosting the Leaf Application Database
  - A database server hosting the Clinical Data (could be the same server as the Application Database SQL Server)

Review the README.md in each folder for setup instructions and deployment notes on that specific environment context. 

If you are exploring Leaf for the first time, use the 'local_development' approach to install Leaf entirely on your desktop with a single command.


## Future Work
This approach is built around locally hosted Docker with a Docker Compose definition, either on your local laptop, or on a virtual server you own and control. Guidance about the best way of translating this setup to one of the popular cloud providers still remains to be vetted and tested. Typically each provider has their own YAML format replacement for the docker compose file. Here are a couple of links to get you started:

- Amazon ECS: https://www.docker.com/blog/docker-compose-from-local-to-amazon-ecs/
- Google Firebase / Cloud Build: https://docs.cloud.google.com/build/docs/configuring-builds/create-basic-configuration
- Azure: https://learn.microsoft.com/en-us/azure/container-instances/container-instances-multi-container-yaml  


## References

### Leaf
- https://leafdocs.rit.uw.edu/installation/

### Gitlab CI
- https://docs.gitlab.com/runner/
- https://docs.gitlab.com/ci/
- https://docs.gitlab.com/ci/variables/
- https://docs.gitlab.com/ci/docker/using_docker_build/

### Github Actions
- https://docs.github.com/en/actions/reference/runners/self-hosted-runners
- https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job