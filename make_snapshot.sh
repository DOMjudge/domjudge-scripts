#!/bin/sh
#
# Script to publish a snapshot package, ChangeLog and admin-manual on
# the public page at https://www.domjudge.org/snapshot/. Alternatively,
# when a git URL is passed only a snapshot package is generated.

set -e

#DEBUG=1

PUBDIR=~/public_html/snapshot
DJDIR=domjudge-snapshot-`date +%Y%m%d`
GITURL="https://github.com/DOMjudge/domjudge.git"

# If a git repo URL is passed, don't update the website.
if [ -n "$1" ]; then
	GITURL="$1" ; shift
	PUBDIR=
fi

[ "$DEBUG" ] && set -x
quiet()
{
	if [ "$DEBUG" ]; then
		$@
	else
		$@ > /dev/null 2>&1
	fi
}

TEMPDIR=`mktemp -d /tmp/domjudge-make_snapshot-XXXXXX`
cd $TEMPDIR

git clone -q --no-checkout --depth 1 "$GITURL" dj-clone

( cd dj-clone && git archive --prefix=$DJDIR/ --format=tar refs/heads/main ) | tar x

# Add released tag for revision information:
sed -i "s/PUBLISHED =.*/PUBLISHED = `date +%Y-%m-%d`/" $DJDIR/paths.mk.in

quiet make -C $DJDIR dist
tar -cf $DJDIR.tar $DJDIR
gzip -9 $DJDIR.tar

if [ -n "$PUBDIR" ]; then
	rm -rf $PUBDIR/*
	mkdir -p $PUBDIR/manual
	cp -r $DJDIR/doc/manual/build/html/*                     $PUBDIR/manual/
	cp $DJDIR/doc/manual/build/team/domjudge-team-manual.pdf $PUBDIR/
	cp $DJDIR.tar.gz $DJDIR/ChangeLog                        $PUBDIR/
	cd /
fi

[ "$DEBUG" ] || rm -rf $TEMPDIR

exit 0
