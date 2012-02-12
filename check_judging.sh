#!/bin/sh
#
# Usage: $0 [-o '<mysql-opts>'] [-d <databasename>] [-i <install-dir>] \
#           [-j <judgehost>] [-w <XML-scoreboard-URL>] \
#           <initial-DB.sql> <sources-dir> <judgings-file> [<standings-file>]
#
# Runs a fully automated backend test by submitting sources to a
# running system and compare the outcomes with expected, known results.
#
# This script requires a fully configured maintainer-install; if no
# <install-dir> is given, the DOMjudge installation is expected in the
# current directory.
#
# First, the file <initial-DB.sql> is loaded into the DOMjudge
# database, and should contain a pristine contest state without any
# submissions or judgings present. Any data present is cleared!
#
# Then all submissions in <sources-dir> are submitted into the system.
# These files should follow naming conventions as used by the scripts
# 'misc-tools/{restore_sources2db,save_sources2file}'; their
# modification time is used as submission time.
#
# The judging results are compared with those in the <judgings-file>.
# If the '-w' option and a <standings-file> are given, then then final
# scoreboard is downloaded from the plugin web interface (note that a
# htpasswd user:pass combination can be passed via the URL) and
# compared to the data in <standings-file>.

set -e

PROGNAME=$0

MYSQLOPTS=''
DBNAME='domjudge'
INSTALLDIR='.'
JUDGEHOST=${HOSTNAME:-`hostname`}
SCOREURL=''

# Maximum age of last polltime in seconds before we declare the
# judgehost crashed.
MAXPOLL=180

# Parse command-line options:
while getopts ':o:d:i:j:w:' OPT ; do
	case "$OPT" in
		o) MYSQLOPTS=$OPTARG ;;
		d) DBNAME=$OPTARG ;;
		i) INSTALLDIR=$OPTARG ;;
		j) JUDGEHOST=$OPTARG ;;
		w) SCOREURL=$OPTARG ;;
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

if [ $# -lt 3 ]; then
	echo "Error: insufficient arguments."
	exit 1
fi
INITDBSQL=$1
SOURCESDIR=$2
JUDGINGSFILE=$3
STANDINGSFILE=$4
if [ ! -f "$INITDBSQL" -o ! -r "$INITDBSQL" ]; then
	echo "Error: cannot read initial DB SQL file '$INITDBSQL'."
	exit 1
fi
if [ ! -d "$SOURCESDIR" -o ! -r "$SOURCESDIR" ]; then
	echo "Error: cannot open sources directory '$SOURCESDIR'."
	exit 1
fi
if [ ! -f "$JUDGINGSFILE" -o ! -r "$JUDGINGSFILE" ]; then
	echo "Error: cannot read judgings file '$JUDGINGSFILE'."
	exit 1
fi

# Clean database and load initial SQL data:
(
	echo "DROP DATABASE IF EXISTS \`$DBNAME\`;"
	echo "CREATE DATABASE \`$DBNAME\` DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
) | mysql $MYSQLOPTS
mysql $MYSQLOPTS "$DBNAME" < "$INITDBSQL"

# Cleanup any previous judging contents:
mv     "$INSTALLDIR/output/log/judge.$JUDGEHOST.log" \
       "$INSTALLDIR/output/log/judge.$JUDGEHOST.log.old-$$"
rm -rf "$INSTALLDIR/output/judging/$JUDGEHOST"

# Upgrade DB schema to recent version:
"$INSTALLDIR"/sql/dj-setup-database upgrade

# Check DB structure to see if upgraded correctly:
CHECKDB="`dirname $PROGNAME`/check_db-struct.sh"
if [ -x "$CHECKDB" ]; then
	$CHECKDB ${MYSQLOPTS:+-o "$MYSQLOPTS"} -d "$DBNAME" \
	         -l "$INSTALLDIR"/sql/mysql_db_structure.sql
fi

# Submit all sources under SOURCESDIR:
"$INSTALLDIR"/misc-tools/restore_sources2db "$SOURCESDIR"

# Start the judgedaemon and check when judging is done or hangs:
echo "Starting judgedaemon on '$JUDGEHOST', `date`."
JUDGEPID=`"$INSTALLDIR"/judge/judgedaemon -d 2>&1 | grep ' PID = ' | sed 's/.* PID = //'`
if ! ps -p "$JUDGEPID" > /dev/null 2>&1 ; then
	echo "Error: the judgedaemon seems have failed to start..."
	exit 1
fi
while sleep 30 ; do
	lastpoll=`echo "SELECT (UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(polltime)) \
	            FROM judgehost WHERE hostname = '$JUDGEHOST'" | \
		mysql -N $MYSQLOPTS "$DBNAME"`
	lastjudge=`echo "SELECT (UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(endtime)) \
	           FROM judging WHERE result IS NOT NULL ORDER BY endtime DESC LIMIT 1" | \
		mysql -N $MYSQLOPTS "$DBNAME"`

	if [ "$lastpoll" = 'NULL' ]; then
		echo "Error: the judgedaemon seems have failed to start..."
		exit 1
	fi
	if [ "$lastpoll" -gt $MAXPOLL ] || ! ps -p "$JUDGEPID" > /dev/null 2>&1 ; then
		echo "Error: the judgedaemon seems to have crashed..."
		exit 1
	fi
	if [ "$lastjudge" != 'NULL' -a "$lastjudge" -gt $((lastpoll+10)) ]; then
		break
	fi
done
echo "Stopping judgedaemon (PID = $JUDGEPID), `date`."
kill -HUP $JUDGEPID

# Check the results:
WARNCOUNT=0
while read CID SID RESULT ; do
	DBRESULT=`echo "SELECT result FROM judging WHERE submitid = '$SID' AND valid = '1'" | \
		mysql -N $MYSQLOPTS "$DBNAME"`

	if [ "$DBRESULT" = "$RESULT" ]; then
		echo "UPDATE judging SET verified = '1', jury_member = 'check_judging' \
		      WHERE submitid = '$SID' AND valid = '1';" | \
			mysql $MYSQLOPTS "$DBNAME"
	else
		echo "Warning: c$CID s$SID, result '$DBRESULT' does not match '$RESULT'."
		WARNCOUNT=$((WARNCOUNT+1))
	fi
done < "$JUDGINGSFILE"

if [ $WARNCOUNT -gt 0 ]; then
	echo "Error: $WARNCOUNT submissions have non-matching results."
fi

if [ -n "$SCOREURL" -a -f "$STANDINGSFILE" ]; then
	SCOREXSLT="`dirname $PROGNAME`/scoreboard_xml2csv.xslt"
	if ! wget -q "$SCOREURL" -O - | xsltproc "$SCOREXSLT" - | \
		diff -U1 "$STANDINGSFILE" - ; then
		echo "Error: mismatch in final scores."
		WARNCOUNT=$((WARNCOUNT+1))
	fi
fi

[ $WARNCOUNT -gt 0 ] && exit 1

exit 0
