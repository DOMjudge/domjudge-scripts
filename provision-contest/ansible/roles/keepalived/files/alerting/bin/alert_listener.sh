#!/bin/sh
while true; do
    if [ -f ~/alerting.sh ]; then
        ~/alerting.sh
    fi
    sleep 0.1s
done
