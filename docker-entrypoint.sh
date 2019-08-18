#!/bin/sh
set -e

echo "Running entrypoint at $(date '+%Y/%m/%d %H:%M:%S')..."

# If no certs exist, we create self-signed certs, as nginx/other may refuse to start
# without certificates files, preventing them from serving the challenges.
if [ ! -f /etc/letsencrypt/live/default/privkey.pem ] ||  [ ! -f /etc/letsencrypt/live/default/cert.pem ]; then
    echo "No letsencrypt certificates found. We need self-signed fallback certificates."
    if [ ! -f /etc/letsencrypt/self-signed/privkey.pem ] ||  [ ! -f /etc/letsencrypt/self-signed/cert.pem ]; then
        echo "No self-signed certificates found. We will create some"
        mkdir -p /etc/letsencrypt/self-signed
        openssl req \
            -new \
            -newkey rsa:4096 \
            -days 365 \
            -nodes \
            -x509 \
            -subj "/C=XX/ST=XXX/L=XXX/O=XXX/CN=${DOMAIN}" \
            -keyout /etc/letsencrypt/self-signed/privkey.pem \
            -out /etc/letsencrypt/self-signed/cert.pem
        ln -fs ./self-signed/privkey.pem /etc/letsencrypt/privkey.pem 
        ln -fs ./self-signed/cert.pem /etc/letsencrypt/cert.pem 
    else
        echo "Self-signed certificates already exist."
    fi
fi

if [ "$MODE" = "disabled" ]; then

    echo "YOU ARE IN DISABLED MODE. Set MODE=staging or MODE=production to get a letsencrypt certificate."
    COMMAND="echo '*** certbot would run now if MODE was staging or production. ***'"

else

    # The hook relinks the certificates (to replace self-signed ones)
    FULL_HOOK="ln -fs ./live/${MODE}/privkey.pem /etc/letsencrypt/privkey.pem && ln -fs ./live/${MODE}/cert.pem /etc/letsencrypt/cert.pem"
    if [ ! -z "$HOOK" ]; then
        FULL_HOOK="$FULL_HOOK && $HOOK"
    fi

    COMMAND="certbot certonly --cert-name ${MODE} --webroot --webroot-path /challenges --non-interactive --agree-tos -m ${EMAIL} -d ${DOMAIN} --deploy-hook '$FULL_HOOK'"
    if [ "$MODE" != "production" ]; then
        echo "YOU ARE IN STAGING MODE. Set MODE=production to generate a real certificate."
        COMMAND="$COMMAND --staging"
    fi

fi

echo "We run the command once (initial check)..."
eval "$COMMAND"

echo "First sync was successful!"

echo "We run the hook..."
eval "$FULL_HOOK"

echo "And prepare the following cronjob:"
CRONJOB="0 * * * * $COMMAND"
echo "$CRONJOB"

echo "Installing the cron job..."
echo "$CRONJOB" > /etc/crontabs/root

echo "Starting..."
exec "$@"
