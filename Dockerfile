##################################################
# Notes for GitHub Actions
#       * Dockerfile instructions: https://git.io/JfGwP
#       * Environment variables: https://git.io/JfGw5
##################################################

#########################
# STAGE: GLOBAL
# Description: Global args for reuse
#########################

ARG VERSION="0"

ARG KANIKO_VERSION="master"
#ARG KANIKO_VERSION="v1.3.0"
ARG KANIKO_URL="https://github.com/GoogleContainerTools/kaniko"
ARG GO_ARCH="amd64"

#########################
# STAGE: BUILD
# Description: Build the app
#########################

FROM docker.io/golang:buster AS BUILD

ARG KANIKO_VERSION
ARG KANIKO_URL
ARG GO_ARCH

WORKDIR /go/src/github.com/GoogleContainerTools

RUN \
    git clone --depth 1 --branch ${KANIKO_VERSION} ${KANIKO_URL} \
 && cd kaniko \
 && make GOARCH=${GO_ARCH}

#########################
# STAGE: RUN
# Description: Run the app
#########################

FROM docker.io/alpine:latest as RUN

ARG VERSION

LABEL name="action-kaniko" \
    maintainer="MAHDTech <MAHDTech@salt-labs.dev>" \
    vendor="Salt Labs" \
    version="${VERSION}" \
    summary="GitHub Action for building container images with Kaniko" \
    url="https://github.com/salt-labs/action-kaniko" \
    org.opencontainers.image.source="https://github.com/salt-labs/action-kaniko"

WORKDIR /

RUN \
    apk update \
 && apk add --no-cache\
            git \
            gnupg \
            bash \
            curl \
            wget \
            zip \
            jq \
            tzdata \
 && rm -rf /var/cache/apk/

RUN mkdir -p /kaniko/.docker

COPY --from=BUILD "/go/src/github.com/GoogleContainerTools/kaniko/out/executor" "/kaniko/executor"
COPY --from=BUILD "/go/src/github.com/GoogleContainerTools/kaniko/files/ca-certificates.crt" "/kaniko/ssl/certs/"

COPY "LICENSE" "README.md" /

COPY "scripts" "/scripts"

ENV PATH /kaniko:/scripts/:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/bin:/sbin

ENV HOME /kaniko
ENV DOCKER_CONFIG /kaniko/.docker/
ENV SSL_CERT_DIR /kaniko/ssl/certs

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
#CMD [ "--help" ]
