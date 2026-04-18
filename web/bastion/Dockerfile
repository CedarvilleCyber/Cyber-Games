FROM alpine:latest

# Install SSH and bash
RUN apk add --no-cache openssh bash sudo shadow

# Copy setup script
COPY setup_scoring_users.sh /tmp/setup_scoring_users.sh
RUN chmod +x /tmp/setup_scoring_users.sh && /tmp/setup_scoring_users.sh && rm /tmp/setup_scoring_users.sh

# Generate SSH host keys
RUN ssh-keygen -A

# Expose SSH port
EXPOSE 22

# Start SSH daemon
CMD ["/usr/sbin/sshd", "-D"]