FROM docker:latest

LABEL maintainer="<docker-plugin@spritsail.io>"

ADD *.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh

ENTRYPOINT [ "sh", "-c", "/usr/local/bin/publish.sh" ]
