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

DBSTRUCT=` mktemp /tmp/domjudge-db__sql.XXXXXX`
SVNSTRUCT=`mktemp /tmp/domjudge-svn_sql.XXXXXX`
SQLTMP=`   mktemp /tmp/domjudge-tmp_sql.XXXXXX`

# Filter SQL expression for comments and unimportant changes
# like auto_increment counters:
sqlfilter()
{
	grep -vE '^(/\*|--|$)' | \
	sed 's/ \(DEFAULT CHARSET\|AUTO_INCREMENT\|ENGINE\)=[^ ]*//g;/_client *= /d'
}

if [ $# -ge 1 ]; then
	LOCALSQL=$1
fi

if [ $# -ge 2 ]; then
	DBNAME=$2
fi

mysqldump $MYSQLOPTS -n -d -Q --skip-add-drop-table "$DBNAME" | \
	sqlfilter > $DBSTRUCT

if [ -n "$LOCALSQL" ]; then
	cp "$LOCALSQL" $SQLTMP
else
	svn export -q --non-interactive "$SVNURL" $SQLTMP
fi
cat $SQLTMP | sqlfilter > $SVNSTRUCT

diff -ibw -u $DBSTRUCT $SVNSTRUCT || true

rm -f $SQLTMP $DBSTRUCT $SVNSTRUCT
