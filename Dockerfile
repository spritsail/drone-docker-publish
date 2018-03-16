FROM docker:latest

LABEL maintainer="Spritsail <docker-plugin@spritsail.io>" \
      org.label-schema.vendor="Spritsail" \
      org.label-schema.name="docker-publish" \
      org.label-schema.description="A Drone CI plugin for tagging and pushing built Docker images"

ADD *.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh

ENTRYPOINT [ "/usr/local/bin/publish.sh" ]
