#!/bin/bash

echo "Starting Nginx in background..."
nginx -g "daemon off;" &
NGINX_PID=$!

echo "Waiting for Nginx to start..."
sleep 5

# Get the hostname (or passed domain)
DOMAIN=${CERT_DOMAIN:-localhost}
EMAIL=${CERT_EMAIL:-admin@ncaecybergames.org}

echo "Attempting to generate certificate for ${DOMAIN} from CA..."
# Try to get the cert from the custom CA. We use --standalone or --nginx plugin
# The problem says: certbot --nginx --server https://ca.ncaecybergames.org/acme/acme/directory

certbot --nginx \
    --server https://ca.ncaecybergames.org/acme/acme/directory \
    --non-interactive --agree-tos -m "$EMAIL" \
    -d "$DOMAIN"

if [ $? -eq 0 ]; then
    echo "Certificate successfully generated!"
    # Replace the paths in nginx.conf with the real certbot paths
    sed -i "s|/etc/nginx/ssl/cert.pem|/etc/letsencrypt/live/$DOMAIN/fullchain.pem|g" /etc/nginx/conf.d/nginx.conf
    sed -i "s|/etc/nginx/ssl/key.pem|/etc/letsencrypt/live/$DOMAIN/privkey.pem|g" /etc/nginx/conf.d/nginx.conf
    nginx -s reload
else
    echo "Failed to get certificate from CA. Falling back to self-signed."
fi

# Set up cron job for cert renewal
echo "0 12 * * * certbot renew --no-random-sleep-on-renew --nginx --post-hook 'nginx -s reload'" > /etc/crontabs/root
crond -b -l 8

# Wait for Nginx process
wait $NGINX_PID
