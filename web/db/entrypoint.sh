#!/bin/bash
set -e

# Forward port 22 to bastion container (handled by docker-compose port mapping now)
# Execution falls through to postgres
exec docker-entrypoint.sh "$@"