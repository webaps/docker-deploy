FROM docker:stable

LABEL 'name'='Docker Deployment Action'
LABEL 'maintainer'='Nick Verschoor <nick@webaps.io>'

LABEL 'com.github.actions.name'='Docker Deployment'
LABEL 'com.github.actions.description'='Zero-downtime deployments to docker over ssh'
LABEL 'com.github.actions.icon'='send'
LABEL 'com.github.actions.color'='green'

RUN apk --no-cache add \
    openssh-client \
    rsync

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]