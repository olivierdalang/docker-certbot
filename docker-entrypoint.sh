#!/bin/sh
set -e

echo "Running entrypoint at $(date '+%Y/%m/%d %H:%M:%S')..."

# Assert configuration is correct
if [ "$MODE" != "disabled" ] && [ "$MODE" != "staging" ] && [ "$MODE" != "production" ]; then
    echo "ERROR ! MODE must be one of 'disabled', 'staging' or 'production'."
    exit 1
fi

# We create self-signed certs as fallback while we get actual certificates from letsencrypt,
# as missing certs may prevent webservers from starting and thus serving the challenges.
if [ ! -f /etc/letsencrypt/self-signed/privkey.pem ] ||  [ ! -f /etc/letsencrypt/self-signed/cert.pem ]; then
    echo "No self-signed certificates found. Generating self-signed certificates..."
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
else
    echo "Existing self-signed certificates found."
fi

# The pre_hook links to the self-signed certificates
PRE_HOOK="ln -fs ./self-signed/privkey.pem /etc/letsencrypt/privkey.pem && ln -fs ./self-signed/cert.pem /etc/letsencrypt/cert.pem"

# The post_hook relinks the certificates (to replace self-signed ones) and then runs the provided HOOK
DEPLOY_HOOK="ln -fs ./live/${MODE}/privkey.pem /etc/letsencrypt/privkey.pem && ln -fs ./live/${MODE}/cert.pem /etc/letsencrypt/cert.pem && $HOOK"

if [ "$MODE" = "disabled" ]; then

    echo "YOU ARE IN DISABLED MODE. Set MODE=staging or MODE=production to get a letsencrypt certificate."

    # We juse a placeholder command, showing what would happen if mode was staging or production
    COMMAND="echo '*** certbot would run now if MODE was staging or production. ***'"

else

    COMMAND="certbot certonly --cert-name ${MODE} --webroot --webroot-path /challenges --non-interactive --agree-tos -m ${EMAIL} -d ${DOMAIN} --pre-hook '$PRE_HOOK' --deploy-hook '$DEPLOY_HOOK'"

    if [ "$MODE" != "production" ]; then
        echo "YOU ARE IN STAGING MODE. Set MODE=production to generate a real certificate."
        COMMAND="$COMMAND --staging"
    fi

fi

# We must manually run the PRE_HOOK to link to the self-signed certificates in case
# mode was changed to "disabled"
if [ "$MODE" = "disabled" ]; then
    eval "$PRE_HOOK"
fi

echo "We run the command once to make sure it works..."
set +e
eval "$COMMAND"
set -e

if [ $? -ne 0 ]; then
    echo "FAILURE !"
    if [ "$MODE" = "production" ]; then
        echo "Waiting for 60 seconds to avoid hitting letsencrypt limit too quickly"
        sleep 60
    fi
    exit 1
else
    echo "SUCCESS !"
fi

# We must manually run the DEPLOY_HOOK too in case mode was switched back to "staging" or "production"
# but the certificates were not due for renewal.
if [ "$MODE" != "disabled" ]; then
    eval "$DEPLOY_HOOK"
fi

echo "Preparing the following cronjob :"
CRONJOB="0 */6 * * * $COMMAND"
echo "$CRONJOB"
echo "$CRONJOB" > /etc/crontabs/root

echo "Starting cron..."
exec "$@"
