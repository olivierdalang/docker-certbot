# Certbot setup for Docker

Certbot setup for Docker. [Docker hub repository](https://hub.docker.com/r/olivierdalang/certbot/).

Benefits:
- in a separate container
- runs cron in container
- can restart/reload other containers through docker socket
- creates self-signed certificates as a fallback (e.g. when developing on localhost)

## Example

In your `docker-compose.yml`:

```yaml
services:
  ...
  # add the certbot service
  certbot:
    image: olivierdalang/certbot:latest
    environment:
      - EMAIL=admin@example.com
      - DOMAINS=example.com,www.example.com
      - MODE=staging
      - HOOK=docker restart mystack_nginx_1
    volumes:
      - certs:/etc/letsencrypt
      - challenges:/challenges
      - /var/run/docker.sock:/var/run/docker.sock

  # mount the volumes on your server
  nginx/apache/uwsgi/...:
    ...
    volumes:
      ...
      - certs:/certs/
      - challenges:/challenges/

# volumes definition
volumes:
  ...
  certs:
  challenges:
```

Set `EMAIL` and `DOMAINS` accordingly. `DOMAINS` can be a single domain, or a list of comma-separated domains (Certbot will generate a certificate covering all the domains, but the self-signed certificate will only use the first one)

Set `MODE` to `production` to get real certificates (but first: check that it works, as you may hit API limit quickly if anything goes wrong). You can also set it to `disabled` to skip completely letsencrypt (you'd only get the self-signed certificates, which can be enough for development). Defaults to `staging`.

Set `HOOK` to the command to be run after succesful renewal. This allows to reload/restart the webservers.
The container has access to the main docker socket and can thus run the same docker commands as the host.

Configure your webserver to serve `/.well-known` from `/challenges/.well-known` and to load the certificates from `/certs/cert.pem` and `/certs/privkey.pem`.

### Sample config for Nginx:

```nginx
# nginx.conf

http {

    # Default server on port 80 redirects to HTTPS (except for certbot challenge)
    server {
        listen 80 default_server;
        location /.well-known {
            alias /challenges/.well-known;
            include  /etc/nginx/mime.types;
        }
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # Default server on port 443
    server {
        listen          443 ssl default_server;

        ssl_certificate     /certs/cert.pem;
        ssl_certificate_key /certs/privkey.pem;

        # Replace this section
        location / {
            ...
        }
    }
}
```

### Sample config for UWSGI:

```
uwsgi \
    ...
    # port 80 must be open for the challenge
    --http 0.0.0.0:80 \
    # this is our main socket with the certificates
    --https 0.0.0.0:443,/certs/cert.pem,/certs/privkey.pem \
    # serve the challenge
    --static-map /.well-known=/challenges/.well-known \
    # any request to /.well-known/* is served as is
    --route-if 'startswith:${REQUEST_URI};/\\.well-known/ continue:${REQUEST_URI}' \
    # any other request to HTTP is redirected to HTTPS
    --route-if-not 'equal:${HTTPS};on redirect-permanent:https://${HTTP_HOST}${REQUEST_URI}' \
    ...
```
