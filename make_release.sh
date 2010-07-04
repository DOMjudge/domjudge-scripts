#!/bin/sh
# $Id$
#
# Script to create a DOMjudge release package. Release file is
# generated in the current directory.

TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`

svn -q export https://secure.a-eskwadraat.nl/svn/domjudge/trunk $TEMPDIR/domjudge

OWD="$PWD"

cd $TEMPDIR/domjudge

VERSION="`cat README | head -n 1 | sed 's/.*version //'`"
CHLOG="`grep ^Version ChangeLog | head -n 1`"

# Ignore libmcrypt warnings when running autoconf.
make QUIET=1 dist 2>&1 | grep -v libmcrypt.m4

# Check for renamed SQL upgrade file
if [ -f sql/upgrade/upgrade_*SVN.sql ]; then
	echo "WARNING: SQL upgrade file to an SVN was found, should probably be renamed!"
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
