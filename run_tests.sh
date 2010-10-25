#!/bin/sh -e
# $Id$
#
# Cronjob script to automatically run the following checks:
# - 'make build' works
# - php/shell script syntax checks
# - testsuite tests
# - HTML validation

#DEBUG=1

LIVESYSTEMDIR=~/system
LIVEURLPREFIX='http://domjudge.a-eskwadraat.nl/domjudge/'

JUDGEUSER=domjudge_jury
JUDGEPASS=passwordhere

PLUGINUSER=jury
PLUGINPASS=jury

[ "$DEBUG" ] && set -x
quiet()
{
	if [ "$DEBUG" ]; then
		$@
	else
		$@ &> /dev/null
	fi
}

# Create an export of fresh svn trunk sources:
TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
svn export -q https://secure.a-eskwadraat.nl/svn/domjudge/trunk $TEMPDIR/system
cd $TEMPDIR/system

# Test 'make config build docs':
make -k QUIET=1 CONFIGURE_FLAGS='--disable-submitclient' \
	maintainer-conf 2>&1 | grep -v "^/usr/share/aclocal/" || true
make -k QUIET=1 build docs 2>&1

# Run DOMjudge internal tests:
cd tests
./syntax
./tests -q

cd ~

[ "$DEBUG" ] || rm -rf $TEMPDIR

# Validate 'svn up'-ed checkout under http://domjudge.a-eskwadraat.nl/domjudge
# (we cannot use a fresh checkout due to missing website config)
cd $LIVESYSTEMDIR && svn -q up

URLS='
.
plugin/scoreboard.php
plugin/event.php?fromid=1&toid=50
public
public/team.php?id=domjudge
team
team/clarifications.php
team/clarification.php
jury
jury/balloons.php
jury/checkconfig.php
jury/clarification.php
jury/clarifications.php
jury/contests.php
jury/contest.php?cmd=add
jury/genpasswds.php
jury/index.php
jury/judgehosts.php
jury/judgehosts.php?cmd=edit&referrer=judgehosts.php
jury/judgehost.php?id=max
jury/languages.php
jury/language.php?cmd=add
jury/problems.php
jury/problem.php?id=fltcmp
jury/problem.php?id=fltcmp&cmd=edit
jury/refresh_cache.php
jury/scoreboard.php
jury/show_source.php?id=1
jury/submission.php?id=1
jury/submission.php?id=91
jury/submission.php?id=94
jury/submissions.php?view[0]
jury/submissions.php?view[1]
jury/submissions.php?view[2]
jury/team_affiliations.php
jury/team_affiliation.php?id=A-Es2
jury/team_categories.php
jury/team_category.php?id=1
jury/team.php?id=domjudge
jury/team.php?id=domjudge&cmd=edit
jury/teams.php
jury/testcase.php?probid=hello'

# jury/show_source.php?id=61

OFS="$IFS"
IFS='
'

XSLTTMP=`mktemp /tmp/domjudge-xslt.XXXXXX`
cat > $XSLTTMP <<EOF
<?xml version="1.0" encoding="utf-8"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

</xsl:stylesheet>
EOF

for i in $URLS ; do
	url="$LIVEURLPREFIX$i"
	# Special-case plugin interface for user/pass and XML output:
	if [ "${i#plugin/}" != "$i" ]; then
		output=`wget -q --user=$PLUGINUSER --password=$PLUGINPASS -O - "$url" 2>&1`
		if ! echo "$output" | head -n 2 | grep '^<root>' 2>&1 >/dev/null ; then
			echo -e "Errors found in '$url'\n$output"
		fi
		continue
	fi
	if ! output=`wget -q --user=$JUDGEUSER --password=$JUDGEPASS -O - "$url" 2>&1 | \
		xsltproc --noout --nowrite --nonet $XSLTTMP - 2>&1` || \
		[ "$output" ] ; then

		echo -e "Errors found in '$url'\n$output"
	fi
done
IFS="$OFS"

[ "$DEBUG" ] || rm -f $XSLTTMP

exit 0
