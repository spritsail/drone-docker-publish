ARG DOCKER_VER=28-cli

FROM docker:${DOCKER_VER}

ARG VCS_REF
ARG DOCKER_VER

LABEL org.opencontainers.image.authors="Spritsail <docker-plugin@spritsail.io>" \
      org.opencontainers.image.title="docker-publish" \
      org.opencontainers.image.description="A Drone CI plugin for tagging and pushing built Docker images" \
      org.opencontainers.image.version=${VCS_REF} \
      io.spritsail.version.docker=${DOCKER_VER}

ADD --chmod=755 *.sh /usr/local/bin/
RUN apk --no-cache add curl jo jq

ENTRYPOINT [ "/usr/local/bin/publish.sh" ]
