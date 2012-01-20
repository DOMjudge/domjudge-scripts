#!/bin/sh
#
# Script to create a DOMjudge release package. Release file is
# generated in the current directory.

set -e

TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
GITURL="git://a-eskwadraat.nl/git/domjudge.git"

if [ -z "$1" ]; then
	echo "Error: missing required release tag argument."
	exit 1
fi
TAG="$1" ; shift

OWD="$PWD"
cd $TEMPDIR

git archive --prefix=domjudge/ --format=tar --remote="$GITURL" "$TAG" | tar x

cd domjudge

VERSION="`cat README | head -n 1 | sed 's/.*version //'`"
CHLOG="`grep ^Version ChangeLog | head -n 1`"

if [ "${VERSION%DEV}" != "${VERSION}" ]; then
	echo "WARNING: version string contains 'DEV', should probably be changed!"
fi

# Add released tag for revision information:
sed -i 's/PUBLISHED =.*/PUBLISHED = release/' paths.mk.in

make QUIET=1 dist

# Check for renamed SQL upgrade file
if ls sql/upgrade/upgrade_*DEV.sql >/dev/null 2>&1; then
	echo "WARNING: SQL upgrade file to a DEV version was found, should probably be renamed!"
fi

cd ..

mv domjudge domjudge-$VERSION

tar -cf "domjudge-$VERSION.tar" "domjudge-$VERSION"
gzip -9 "domjudge-$VERSION.tar"

cd "$OWD"

mv $TEMPDIR/domjudge-$VERSION.tar.gz .
rm -rf "$TEMPDIR"

echo "Release file: 'domjudge-$VERSION.tar.gz'"
echo "ChangeLog version: '$CHLOG'"

exit 0
