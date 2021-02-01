# Readme

## Table of Contents

<!-- TOC -->

- [Readme](#readme)
    - [Table of Contents](#table-of-contents)
    - [Workflow Status](#workflow-status)
    - [Description](#description)
    - [Inputs](#inputs)
    - [Outputs](#outputs)
    - [Secrets](#secrets)
    - [Environment Variables](#environment-variables)
    - [Example](#example)

<!-- /TOC -->

## Workflow Status

| Status | Description |
| :----- | :---------- |
| ![Greetings](https://github.com/salt-labs/action-kaniko/workflows/Greetings/badge.svg) | Greets new users to the project. |
| ![Kaniko](https://github.com/salt-labs/action-kaniko/workflows/Kaniko/badge.svg) | Testing and building containers with Kaniko |
| ![Labeler](https://github.com/salt-labs/action-kaniko/workflows/Labeler/badge.svg) | Automates label addition to issues and PRs |
| ![Release](https://github.com/salt-labs/action-kaniko/workflows/Release/badge.svg) | Ships new releases :ship: |
| ![Stale](https://github.com/salt-labs/action-kaniko/workflows/Stale/badge.svg) | Checks for Stale issues and PRs  |

## Description

This GitHub Action uses Google's [Kaniko](https://github.com/GoogleContainerTools/kaniko) project to build and push containers.

---
**NOTE:** This has only been tested with the following container registries:

- GitHub
    - ```docker.pkg.github.com```
    - ```ghcr.io```
- Docker Hub
    - ```docker.io```

---

## Inputs

The following inputs are available:

| Input | Required | Description | Examples |
| :---- | :------- | :---------- | :------ |
| log_level | False | Sets the log level for debugging purposes | ```DEBUG```</br>```INFO```</br>```WARN```</br>```ERR``` |
| registry | False | Sets the Container Registry to push the images | ```docker.pkg.github.com```</br>```docker.io``` |
| registry_username | False | The username to auth with the registry | ```${{secrets.DOCKER_USERNAME}}``` |
| registry_password | False | The password to auth with the registry | ```${{secrets.DOCKER_PASSWORD}}``` |
| registry_namespace | False | The namespace you want the image pushed to. Defaults to the GitHub organization. | ```dockerhubnamespace``` |
| image_name | False | The image name to be used. Defaults to the GitHub repository | ```my_app``` |
| image_tag_prefix | False | A prefix that you want stripped removed from the image tag | ```my_org_name-myapp``` |
| image_tag | False | A Custom image tag to apply | ```my_orgname-myapp-latest``` |
| image_tag_extra | False | Enable to apply an opinionated set of additional tags dependant on the git branch running the Workflow.</br>- ```master (:stable)```</br>- ```feature/* (:feature)```</br>- ```bug/ (:bug)```</br>- ```release/ (:release)``` | ```true```</br>```false``` |
| image_cache_enabled | False | Enable build caching | ```true```</br>```false``` |
| image_cache_repo | False | If the Kaniko cache is enabled, this is the name of the image to store it | ```cache``` |
| image_cache_directory | False | The local directory to store the build cache | ```/cache``` |
| dockerfile | False | The name of the Dockerfile | ```Dockerfile``` |
| extra_args | False | Extra args to pass to Kaniko | ```--reproducible``` |

## Outputs

- None

## Secrets

The following secrets are used by the Action:

| Secret | Description | Example |
| :----- | :---------- | :------ |
| GITHUB_TOKEN | The GitHub Token to access the registry for ```docker.pkg.github.com``` | ```${{secrets.GITHUB_TOKEN}}``` |
| REGISTRY_PAT | A Personal Access Token is required to be passed if using ```docker.io```. The name can be whatever you wish. | ```${{secrets.REGISTRY_PAT}}``` |

**NOTE:** GitHub's new container registry ```ghcr.io``` requires the use of a personal access token, see the documentation at this [link](https://docs.github.com/en/packages/guides/configuring-docker-for-use-with-github-packages#authenticating-to-github-packages)

## Environment Variables

- None

## Example

Refer to the included [examples](./examples "examples") directory.
