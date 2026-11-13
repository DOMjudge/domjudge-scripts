#!/bin/bash
set -eu -o pipefail

# Contains secret $SLACK_URL for posting notifications
. ~/.slack_url.secret

RELEASE_DIR="/srv/http/domjudge/releases"
TAGS_CACHE_DIR="/tmp/release_tags_processed"
RELEASE_REGEX="[0-9]+\.[0-9]+\.[0-9]+((RC|rc)[0-9])?"

notify_channel ()
{
    local MSG="$1"
    # Write to syslog on server
    logger "$1"
    # Notify DOMjudge Slack channel (github-notifications)
    curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$1"'"}' "$SLACK_URL"
}

process_tag ()
{
    local TAG="$1"
    local TARBALL="domjudge-$TAG.tar.gz"
    if [ -f "$TAGS_CACHE_DIR/$TAG" ] || [ -f "$RELEASE_DIR/$TARBALL" ]; then
        # Already (being) processed
        return 0
    fi
    touch "$TAGS_CACHE_DIR/$TAG"
    if [[ $TAG =~ ^$RELEASE_REGEX$ ]]; then
        # To find the signer key of a earlier tag:
        # gpg --search 780355B5EA6BFC8235A99C4B56F61A79401DAC04
        # And if one trusts the internet to be correct
        # gpg --recv-keys 780355B5EA6BFC8235A99C4B56F61A79401DAC04
        if git verify-tag "$TAG" ; then
            (cd $RELEASE_DIR && ~/domjudge-scripts/make_release.sh "$TAG")
            notify_channel "Tarball finished ($TAG).\nURL: https://www.domjudge.org/releases/$TARBALL"
        else
            notify_channel "Untrusted tag ($TAG)"
        fi
    fi
}

mkdir -p "$TAGS_CACHE_DIR"

# For `git tag` and `git verify-tag` commands to work:
cd ~/git/mirror/domjudge.git

git tag | \
while read -r tag; do
    process_tag "$tag"
done
