#!/bin/sh
#
# Usage: $0 [-o '<mysql-opts>'] [-d <databasename>] [-l <local-sql-file>]
#
# Check whether DOMjudge mysql database structure is consistent with
# git repository: outputs diff.

set -e

MYSQLOPTS='-u domjudge_jury -p'
DBNAME='domjudge'
LOCALSQL=''

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

# Parse command-line options:
while getopts ':o:d:l:' OPT ; do
	case "$OPT" in
		o) MYSQLOPTS=$OPTARG ;;
		d) DBNAME=$OPTARG ;;
		l) LOCALSQL=$OPTARG ;;
		:)
			echo "Error: option '$OPTARG' requires an argument."
			exit 1
			;;
		?)
			echo "Error: unknown option '$OPTARG'."
			exit 1
			;;
		*)
			echo "Error: unknown error reading option '$OPT', value '$OPTARG'."
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

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
