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

if [ -n "$1" ]; then
	GITURL="$1" ; shift
fi

OWD="$PWD"
cd $TEMPDIR

git archive --prefix=domjudge/ --format=tar --remote="$GITURL" "$TAG" | tar x

cd domjudge

VERSION="`cat README | head -n 1 | sed 's/.*version //'`"
CHLOG="`grep ^Version ChangeLog | head -n 1`"

# Check for non-release version
if [ "${VERSION%DEV}" != "${VERSION}" ] || \
   [ "${VERSION%SVN}" != "${VERSION}" ]; then
	echo "WARNING: version string contains 'DEV' or 'SVN', should probably be changed!"
fi

# Check for renamed SQL upgrade file
if ls sql/upgrade/upgrade_*DEV.sql >/dev/null 2>&1 || \
      sql/upgrade/upgrade_*SVN.sql >/dev/null 2>&1 ; then
	echo "WARNING: found SQL upgrade file to DEV/SVN version, should probably be renamed!"
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

echo "Release file: 'domjudge-$VERSION.tar.gz'"
echo "ChangeLog version: '$CHLOG'"

exit 0
