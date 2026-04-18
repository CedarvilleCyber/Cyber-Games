FROM nginx:alpine

# Install certbot and openssl
RUN apk add --no-cache certbot certbot-nginx openssl dcron bash sudo shadow

# Copy the Root CA and trust it
COPY ca.crt /usr/local/share/ca-certificates/ca.ncaecybergames.org.crt
RUN cat /usr/local/share/ca-certificates/ca.ncaecybergames.org.crt >> /etc/ssl/certs/ca-certificates.crt

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Create a self-signed fallback cert just so nginx can start before certbot runs
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Org/CN=localhost"

# Create a script to run certbot and start nginx
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
