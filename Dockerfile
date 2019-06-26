FROM certbot/certbot:v0.33.1

# install docker-in-docker
ARG DOCKERVERSION=18.03.1-ce
RUN apk add curl
RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz && \
    tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 -C /usr/local/bin docker/docker && \
    rm docker-${DOCKERVERSION}.tgz

VOLUME "/challenges"
VOLUME "/certs"

ADD docker-entrypoint.sh /docker-entrypoint.sh 
RUN chmod +x /docker-entrypoint.sh

# restore default entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["crond", "-f"]
