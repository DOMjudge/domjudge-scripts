#!/bin/bash

set -eu

. ~/.tagrelease

main=master

RELEASE_DIR="/srv/http/domjudge/releases"

notify_channel () {
    # Local debug
    echo "$1"
    # When cron is run often one should have time to
    # fix the issue.
    if [ ! -f /tmp/$2 ]; then
        # Write to syslog on server
        logger "$1"
        DATA='{"text":"'"$1"'"}'
        # Notify DOMjudge Slack channel (github-notifications)
        # SLACK_URL should be exported in the .bashrc (it should be secret)
        curl -X POST -H 'Content-type: application/json' --data "$DATA" "$SLACK_URL"
        touch /tmp/$2
    fi
}

process_tag () {
    TAG="$1"
    NUMB="[0-9]+"
    DOT="\."
    RELEASE="$NUMB$DOT$NUMB$DOT$NUMB"
    OPTRC="((RC|rc)[0-9])?"
    if [[ $TAG =~ ^$RELEASE$OPTRC$ ]]; then
       # TODO: check if the file already exists
       if [ -f "$RELEASE_DIR/domjudge-$TAG.tar.gz" ]; then
           # Tag is already handled
           return 0
       fi
       # To find the signer key of a earlier tag:
       # gpg --search 780355B5EA6BFC8235A99C4B56F61A79401DAC04
       # And if one trusts the internet to be correct
       # gpg --recv-keys 780355B5EA6BFC8235A99C4B56F61A79401DAC04
       if git verify-tag $TAG; then
           # At this point the tarball should already be locally tested
           ~/domjudge-scripts/make_release.sh "$TAG"
           mv domjudge-$TAG.* $RELEASE_DIR/
           notify_channel "Tarball finished ($TAG).\nURL: https://www.domjudge.org/releases/domjudge-$TAG.tar.gz" "$TAG"
       else
           notify_channel "Untrusted tag ($TAG)" "$TAG"
       fi
    fi
}

# Reset to main branch
cd ~domjudge/git/domjudge
git checkout $main

while read -r tag; do
    process_tag "$tag"
done <<< "$(git tag)"

