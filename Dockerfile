ARG DOCKER_VER=20.10.2

FROM docker:${DOCKER_VER}

ARG VCS_REF
ARG DOCKER_VER

LABEL maintainer="Spritsail <docker-plugin@spritsail.io>" \
      org.label-schema.vendor="Spritsail" \
      org.label-schema.name="docker-publish" \
      org.label-schema.description="A Drone CI plugin for tagging and pushing built Docker images" \
      org.label-schema.version=${VCS_REF} \
      io.spritsail.version.docker=${DOCKER_VER}

ADD *.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh \
 && apk --no-cache add curl jq

ENTRYPOINT [ "/usr/local/bin/publish.sh" ]
