ARG DOCKER_VER=23.0-rc-cli

FROM docker:${DOCKER_VER}

ARG VCS_REF
ARG DOCKER_VER

LABEL org.opencontainers.image.authors="Spritsail <docker-plugin@spritsail.io>" \
      org.opencontainers.image.title="docker-publish" \
      org.opencontainers.image.description="A Drone CI plugin for tagging and pushing built Docker images" \
      org.opencontainers.image.version=${VCS_REF} \
      io.spritsail.version.docker=${DOCKER_VER}

ADD *.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh \
 && apk --no-cache add curl jq

ENTRYPOINT [ "/usr/local/bin/publish.sh" ]
