#!/bin/sh
#
# Script to create a DOMjudge release package. Release file is
# generated in the current directory.

if [ -z "${CI+x}" ]; then
    set -e
else
    set -eux
    export PS4='(${0}:): - [$?] $ '
fi

GITURL="https://github.com/DOMjudge/domjudge.git"

TEMPDIR=`mktemp -d /tmp/domjudge-make_release-XXXXXX`

if [ -z "$1" ]; then
	echo "Error: missing required release tag argument."
	exit 1
fi

if [ ! -z "${CI+x}" ]; then set +x; fi
TAG="$1" ; shift
if [ ! -z "${CI+x}" ]; then set -x; fi

if [ -n "${1+x}" ]; then
    GITURL="$1" ; shift
fi

OWD="$PWD"
cd $TEMPDIR

git clone -q --no-checkout --depth 1 --single-branch --branch "$TAG" "$GITURL" dj-clone

( cd dj-clone && git archive --prefix=domjudge/ --format=tar "$TAG" ) | tar x

cd domjudge

VERSION="$(cat README* | head -n 10 | grep ' version ' | sed 's/.*version //')"
CHLOG="$(grep ^Version ChangeLog | head -n 1)"

# Check for non-release version
if [ "${VERSION%DEV}" != "${VERSION}" ]; then
    echo "WARNING: version string contains 'DEV', should probably be changed!"
fi

CHLOG_VERSION="$(echo $CHLOG | sed -r 's/^Version ([0-9\.]+) .*$/\1/')"
if [ "$VERSION" != "$CHLOG_VERSION" ]; then
	echo "WARNING: version strings in README* and ChangeLog differ: '$VERSION' != '$CHLOG_VERSION'"
fi

# Add released tag for revision information:
sed -i 's/PUBLISHED =.*/PUBLISHED = release/' paths.mk.in

make QUIET=1 dist

cd ..

mv domjudge domjudge-$VERSION

tar -cf "domjudge-$VERSION.tar" "domjudge-$VERSION"
gzip -9 "domjudge-$VERSION.tar"

cd "$OWD"

mv $TEMPDIR/domjudge-$VERSION.tar.gz .
rm -rf "$TEMPDIR"

sha256sum domjudge-$VERSION.tar.gz > domjudge-$VERSION.tar.gz.sha256sum
if [ -z "${CI+x}" ]; then
    gpg -a --detach-sign --digest-algo SHA256 domjudge-$VERSION.tar.gz
else
    gpg --pinentry-mode loopback --batch --passphrase ${PASS} --detach-sign --armor --digest-algo SHA256 domjudge-$VERSION.tar.gz
fi

echo "Release file: 'domjudge-$VERSION.tar.gz'"
echo "ChangeLog version: '$CHLOG'"

exit 0
