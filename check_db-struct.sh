#!/bin/sh
#
# Usage: $0 [<local-sql-file> [<databasename>]]
#
# Check whether DOMjudge mysql database structure is consistent with
# git repository: outputs diff.

set -e

MYSQLOPTS='-u domjudge_jury -p'
DBNAME='domjudge'

GITURL='git://a-eskwadraat.nl/git/domjudge.git'

DBSTRUCT=` mktemp /tmp/domjudge-db__sql.XXXXXX`
GITSTRUCT=`mktemp /tmp/domjudge-git_sql.XXXXXX`
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
	git archive --format=tar --remote="$GITURL" master \
		sql/mysql_db_structure.sql 2>/dev/null | tar x -O > $SQLTMP
fi
cat $SQLTMP | sqlfilter > $GITSTRUCT

diff -ibw -u $DBSTRUCT $GITSTRUCT || true

rm -f $SQLTMP $DBSTRUCT $GITSTRUCT
