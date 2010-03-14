#!/bin/sh
# $Id$
#
# Usage: $0 [<local-sql-file> [<databasename>]]
#
# Check whether DOMjudge mysql database structure is consistent with
# svn repository: outputs diff.

set -e

SVNURL='https://secure.a-eskwadraat.nl/svn/domjudge/trunk/sql/mysql_db_structure.sql'

MYSQLOPTS='-u domjudge_jury -p'
DBNAME='domjudge'

DBSTRUCT=` tempfile --prefix db__ --suffix .sql`
SVNSTRUCT=`tempfile --prefix svn_ --suffix .sql`
SQLTMP=`tempfile`

if [ $# -ge 1 ]; then
	LOCALSQL=$1
fi

if [ $# -ge 2 ]; then
	DBNAME=$2
fi

mysqldump $MYSQLOPTS -n -d -Q --skip-add-drop-table "$DBNAME" | grep -vE '^(/\*|--|$)' | \
	sed 's/ \(DEFAULT CHARSET\|AUTO_INCREMENT\|ENGINE\)=[^ ]*//g' | \
	sed 's/ default / DEFAULT /;s/ auto_increment / AUTO_INCREMENT /'  | \
	sed '/_client *= /d' > $DBSTRUCT

if [ -n "$LOCALSQL" ]; then
	cp "$LOCALSQL" $SQLTMP
else
	svn export -q --non-interactive "$SVNURL" $SQLTMP
fi
grep -vE '^(/\*|--|$)' $SQLTMP | \
	sed 's/ \(DEFAULT CHARSET\|AUTO_INCREMENT\|ENGINE\)=[^ ]*//g' | \
	sed 's/ default / DEFAULT /;s/ auto_increment / AUTO_INCREMENT /' > $SVNSTRUCT

diff -bw -u $DBSTRUCT $SVNSTRUCT || true

rm -f $SQLTMP $DBSTRUCT $SVNSTRUCT
