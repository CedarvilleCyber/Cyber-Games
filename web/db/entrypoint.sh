#!/bin/bash
set -e

# Forward port 22 to bastion container
socat TCP-LISTEN:22,fork TCP:192.168.3.10:22 &

# Execute the original postgres entrypoint
exec docker-entrypoint.sh "$@"