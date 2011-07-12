#!/bin/sh
# $Id$
#
# Script to create a DOMjudge release package. Release file is
# generated in the current directory.

set -e

TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
SVNURL='https://secure.a-eskwadraat.nl/svn/domjudge'

if [ -z "$1" ]; then
	echo "Error: required branch argument missing. Use e.g. 'branches/X.Y' or 'trunk'."
	exit 1
fi
BRANCH="$1" ; shift

svn -q export "$SVNURL/$BRANCH" $TEMPDIR/domjudge

OWD="$PWD"

cd $TEMPDIR/domjudge

find . -name .gitignore -delete

VERSION="`cat README | head -n 1 | sed 's/.*version //'`"
CHLOG="`grep ^Version ChangeLog | head -n 1`"

if [ "${VERSION%SVN}" != "${VERSION}" ]; then
	echo "WARNING: version string contains 'SVN', should probably be changed!"
fi

find . -name .gitignore -delete

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
