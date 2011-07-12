#!/bin/sh
# $Id$
#
# Script public a snapshot package, ChangeLog en admin-manual on the
# public page at http://domjudge.sourceforge.net/snapshot/.

#DEBUG=1

PUBDIR=~/public_html/snapshot

[ "$DEBUG" ] && set -x
quiet()
{
	if [ "$DEBUG" ]; then
		$@
	else
		$@ &> /dev/null
	fi
}

TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
cd $TEMPDIR

DATE=`date +%Y%m%d`

rm -rf $PUBDIR/*

svn export -q https://secure.a-eskwadraat.nl/svn/domjudge/trunk domjudge-snapshot-$DATE

find domjudge-snapshot-$DATE -name .gitignore -delete
quiet make -C domjudge-snapshot-$DATE dist
find domjudge-snapshot-$DATE -name .gitignore -delete
tar -cf domjudge-snapshot-$DATE.tar domjudge-snapshot-$DATE
gzip -9 domjudge-snapshot-$DATE.tar
cp domjudge-snapshot-$DATE.tar.gz    $PUBDIR
cp domjudge-snapshot-$DATE/ChangeLog $PUBDIR

quiet make -C domjudge-snapshot-$DATE docs
mkdir -p $PUBDIR/admin-manual $PUBDIR/judge-manual
cp domjudge-snapshot-$DATE/doc/admin/{admin-manual*.{html,pdf},*.png} $PUBDIR/admin-manual/
cp domjudge-snapshot-$DATE/doc/judge/judge-manual*.{html,pdf}         $PUBDIR/judge-manual/
cp domjudge-snapshot-$DATE/doc/team/team-manual.pdf                   $PUBDIR/
cd /

[ "$DEBUG" ] || rm -rf $TEMPDIR

exit 0
