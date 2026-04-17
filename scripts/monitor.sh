#!/bin/bash
#
# script to monitor active connections and users

while true; do
    clear
    w
    echo ""
    ss -tulnp
    sleep 2
done
