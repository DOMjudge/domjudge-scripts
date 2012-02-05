#!/bin/sh
#
# Script to publish a snapshot package, ChangeLog en admin-manual on
# the public page at http://domjudge.sourceforge.net/snapshot/.

set -e

#DEBUG=1

PUBDIR=~/public_html/snapshot
DJDIR=domjudge-snapshot-`date +%Y%m%d`
GITURL="file://$HOME/git/domjudge.git"

[ "$DEBUG" ] && set -x
quiet()
{
	if [ "$DEBUG" ]; then
		$@
	else
		$@ > /dev/null 2>&1
	fi
}

TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
cd $TEMPDIR

git archive --prefix=$DJDIR/ --format=tar \
	--remote="$GITURL" refs/heads/master | tar x

# Add released tag for revision information:
sed -i "s/PUBLISHED =.*/PUBLISHED = `date +%Y-%m-%d`/" $DJDIR/paths.mk.in

quiet make -C $DJDIR dist
tar -cf $DJDIR.tar $DJDIR
gzip -9 $DJDIR.tar

rm -rf $PUBDIR/*
mkdir -p $PUBDIR/admin-manual $PUBDIR/judge-manual
cp $DJDIR/doc/admin/admin-manual*.html \
   $DJDIR/doc/admin/admin-manual.pdf   \
   $DJDIR/doc/admin/*.png                $PUBDIR/admin-manual/
cp $DJDIR/doc/judge/judge-manual*.html \
   $DJDIR/doc/judge/judge-manual.pdf     $PUBDIR/judge-manual/
cp $DJDIR/doc/team/team-manual.pdf       $PUBDIR/
cp $DJDIR.tar.gz $DJDIR/ChangeLog        $PUBDIR/
cd /

[ "$DEBUG" ] || rm -rf $TEMPDIR

exit 0
