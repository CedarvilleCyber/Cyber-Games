FROM alpine:latest

# Install Bind9 and tools
RUN apk add --no-cache bind bind-tools bash socat

# Setup bind configuration directories
RUN mkdir -p /var/bind/dyn && \
    chown -R root:named /var/bind && \
    chmod -R 775 /var/bind/dyn

# Copy config files
COPY dns/named.conf /etc/bind/named.conf
COPY dns/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose DNS ports
EXPOSE 53/udp 53/tcp

ENTRYPOINT ["/entrypoint.sh"]
