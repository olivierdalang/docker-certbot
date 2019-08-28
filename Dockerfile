FROM certbot/certbot:v0.37.2

# install docker-in-docker
ARG DOCKERVERSION=19.03.1
RUN apk add --no-cache curl=7.65.1-r0; \
    curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz && \
    tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 -C /usr/local/bin docker/docker && \
    rm docker-${DOCKERVERSION}.tgz

VOLUME "/challenges"
VOLUME "/certs"

ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# default config
ENV HOOK 'echo "No HOOK provided !"'

# restore default entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["crond", "-f"]
