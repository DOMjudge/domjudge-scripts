#!/bin/sh
# $Id$
#
# Script to create a DOMjudge release package. Release file is
# generated in the current directory.

set -e

TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
GITURL="file://$HOME/git/domjudge.git"

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

if [ "${VERSION%SVN}" != "${VERSION}" ]; then
	echo "WARNING: version string contains 'SVN', should probably be changed!"
fi

# Add released tag for revision information:
sed -i 's/PUBLISHED =.*/PUBLISHED = release/' paths.mk.in

# Ignore libmcrypt warnings when running autoconf.
make QUIET=1 dist
# 2>&1 | grep -v libmcrypt.m4

# Check for renamed SQL upgrade file
if ls sql/upgrade/upgrade_*SVN.sql >/dev/null 2>&1; then
	echo "WARNING: SQL upgrade file to an SVN version was found, should probably be renamed!"
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
