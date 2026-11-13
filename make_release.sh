#!/bin/sh
#
# Script to create a DOMjudge release package. Release file is
# generated in the current directory.

set -e

GITURL="https://github.com/DOMjudge/domjudge.git"

TEMPDIR=$(mktemp -d /tmp/domjudge-make_release-XXXXXX)

if [ -z "$1" ]; then
    echo "Error: missing required release tag argument."
    exit 1
fi
TAG="$1" ; shift

if [ -n "$1" ]; then
    GITURL="$1" ; shift
fi

OWD="$PWD"
cd "$TEMPDIR"

git clone -q --no-checkout --depth 1 --single-branch \
    --branch "$TAG" "$GITURL" dj-clone

( cd dj-clone && git archive --prefix=domjudge/ --format=tar "$TAG" ) | tar x

cd domjudge

VERSION="$(cat README* | head -n 10 | grep ' version ' | sed 's/.*version //')"
CHLOG="$(grep ^Version ChangeLog | head -n 1)"

# Check for non-release version
if [ "${VERSION%DEV}" != "${VERSION}" ]; then
    echo "WARNING: version string contains 'DEV', should probably be changed!"
fi

CHLOG_VERSION="$(echo "$CHLOG" | sed -r 's/^Version ([0-9\.]+) .*$/\1/')"
if [ "$VERSION" != "$CHLOG_VERSION" ]; then
    echo "WARNING: version strings in README* and ChangeLog differ:"
    echo "'$VERSION' != '$CHLOG_VERSION'"
fi

# Add released tag for revision information:
sed -i 's/PUBLISHED =.*/PUBLISHED = release/' paths.mk.in
sed -i "s/INSTALL_METHOD\s*=.*/INSTALL_METHOD    = tarball/" paths.mk.in

make QUIET=1 dist

cd ..

mv domjudge "domjudge-$VERSION"

tar -cf "domjudge-$TAG.tar" "domjudge-$VERSION"
gzip -9 "domjudge-$TAG.tar"

cd "$OWD"

mv "$TEMPDIR/domjudge-$TAG.tar.gz" .
rm -rf "$TEMPDIR"

sha256sum "domjudge-$TAG.tar.gz" > "domjudge-$TAG.tar.gz.sha256sum"

#GPG_ARGS="-a --detach-sign --digest-algo SHA256 domjudge-$TAG.tar.gz"
#if [ -t 1 ] ; then
#    # Explicit not quoted!
#    gpg $GPG_ARGS
#else
#    gpg --pinentry-mode=loopback --batch --passphrase-file ~domjudge/sign_key_pass $GPG_ARGS
#fi

echo "Release file: 'domjudge-$VERSION.tar.gz'"
echo "ChangeLog version: '$CHLOG'"

exit 0
