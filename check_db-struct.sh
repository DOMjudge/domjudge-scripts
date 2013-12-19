#!/bin/sh
#
# Usage: $0 [-o '<mysql-opts>'] [-d <databasename>] [-l <local-sql-file>]
#
# Check whether DOMjudge mysql database structure is consistent with
# git repository: outputs diff.

set -e

MYSQLOPTS=''
DBNAME='domjudge'
LOCALSQL=''

GITURL='https://github.com/DOMjudge/domjudge.git'

TEMPDIR=`mktemp -d /tmp/domjudge-check_db-XXXXXX`

DBSTRUCT="$TEMPDIR/db__struct.sql"
GITSTRUCT="$TEMPDIR/git_struct.sql"
SQLTMP="$TEMPDIR/tmp_struct.sql"
GITCLONE="$TEMPDIR/domjudge"

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
# This is a kludge to get a single file from a (remote) git
# repository, but unfortunately git-archive is not supported by the
# http(s) protocol nor by github.
	git clone -q --no-checkout --depth 1 "$GITURL" $GITCLONE
	( cd $GITCLONE && git show HEAD:sql/mysql_db_structure.sql ) > $SQLTMP
fi
cat $SQLTMP | sqlfilter > $GITSTRUCT

diff -ibw -u $DBSTRUCT $GITSTRUCT || true

rm -rf $TEMPDIR
