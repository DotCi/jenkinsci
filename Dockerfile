FROM java:8-jdk-alpine

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000
ENV JENKINS_USER jenkins
ENV JENKINS_UID 1000
ENV JENKINS_GROUP jenkins
ENV JENKINS_GID 1000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN addgroup -g $JENKINS_GID $JENKINS_GROUP
RUN adduser -D -h "$JENKINS_HOME" -u $JENKINS_UID -G $JENKINS_GROUP $JENKINS_USER

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# https://github.com/jenkinsci/docker/issues/239
RUN apk update && apk add ca-certificates && update-ca-certificates && apk add openssl bash ttf-dejavu

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN wget -O /bin/tini https://github.com/krallin/tini/releases/download/v0.5.0/tini-static && chmod +x /bin/tini \
  && echo -e "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

RUN mkdir -p /usr/share/jenkins && wget -O /usr/share/jenkins/jenkins.war http://mirrors.jenkins.io/war-stable/latest/jenkins.war

ENV JENKINS_UC https://updates.jenkins-ci.org
RUN chown -R $JENKINS_USER "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE $JENKINS_SLAVE_AGENT_PORT

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER $JENKINS_USER

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
