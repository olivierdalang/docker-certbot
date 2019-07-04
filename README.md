# Certbot setup for Docker

Certbot setup for Docker. [Docker hub repository](https://hub.docker.com/r/olivierdalang/certbot/).

Benefits :
- in a separate container
- runs cron in container
- can restart/reload other containers through docker socket
- creates self-signed certificates as a fallback (e.g. when developing on localost)

## Example

In you docker-compose :

```
services:
  ...
  # add the certbot service
  certbot:
    image: olivierdalang/certbot:latest
    environment:
      - EMAIL=admin@example.com
      - DOMAIN=example.com
      - STAGING=false
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

Set `EMAIL` and `DOMAIN` accordingly.

Set `STAGING` to `true` to get real certificates (but first : check that it works, as you may hit API limit quickly if anything goes wrong).

Set `HOOK` to the command to be run after succesful renewal. This allows to reload/restart the webservers.
The container has access to the main docker socket and can thus run the same docker commands as the host.

Configure your webserver to server `/.well-known` from `/challenges/.well-known` and to load the certificates keys.

### Sample config for Nginx :

`nginx.conf` :
```

http{

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

### Sample config for UWSGI :

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

## FAQ

### Switching from STAGING to PRODUCTION

You need to delete the certs, as cerbot won't consider the certs are due for renewal.

```
# Remove the certs
docker-compose exec certbot sh -c 'rm -r /etc/letsencrypt/*'
# Restart the stack
docker-compose restart certbot
```

