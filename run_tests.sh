#!/bin/sh
#
# Cronjob script to automatically run the following checks:
# - 'make build' works
# - php/shell script syntax checks
# - testsuite tests
# - HTML validation

set -e

#DEBUG=1

LIVESYSTEMDIR=~/system
LIVEURLPREFIX='http://www.domjudge.org/domjudge/'
GITURL='git://a-eskwadraat.nl/git/domjudge.git'

PLUGINUSER=jury
PLUGINPASS=jury

[ "$DEBUG" ] && set -x
quiet()
{
	if [ "$DEBUG" ]; then
		$@
	else
		$@ > /dev/null 2>&1
	fi
}

# Create an export of fresh git master sources:
TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
git clone -q "$GITURL" $TEMPDIR/system
cd $TEMPDIR/system

# Test 'make config build docs':
make -k QUIET=1 MAINT_CXFLAGS='-O -Wall -fPIE -Wformat -Wformat-security -ansi' \
	maintainer-conf 2>&1 || true
make -k QUIET=1 build docs 2>&1 | \
	sed -n '/warning: variable .dummy. set but not used/{n;x;d;};x;1d;p;${x;p;}' || true

# Run DOMjudge internal tests (remove install-sh script for false positives):
rm install-sh
cd tests
./syntax
./tests -q

cd ~

[ "$DEBUG" ] || rm -rf $TEMPDIR


# Validate DOMjudge webpages running from uptodate git checkout
# (we cannot use a fresh checkout due to missing website config)
cd $LIVESYSTEMDIR && git stash -q && git pull -q && git stash pop -q

URLS='
.
plugin/scoreboard.php
plugin/event.php?fromid=1&toid=50
public/
public/team.php?id=domjudge
team
team/clarification.php
team/clarification.php?id=137
team/scoreboard.php
team/submission_details.php?id=998
team/submission_details.php?id=1163
jury/
jury/balloons.php
jury/clarification.php
jury/clarification.php?id=107
jury/clarifications.php
jury/contests.php
jury/index.php
jury/judgehosts.php
jury/judgehost.php?id=judgehost1
jury/language.php?id=c
jury/languages.php
jury/problems.php
jury/problem.php?id=fltcmp
jury/scoreboard.php
jury/scoreboard.php?country[]=NLD
jury/show_source.php?id=1
jury/submission.php?id=1
jury/submission.php?id=91
jury/submission.php?id=94
jury/show_source.php?id=3
jury/submissions.php?view[0]
jury/submissions.php?view[1]
jury/submissions.php?view[2]
jury/team_affiliations.php
jury/team_affiliation.php?id=UU
jury/team_categories.php
jury/team_category.php?id=1
jury/team.php?id=domjudge
jury/teams.php
jury/testcase.php?probid=hello
jury/auditlog.php
jury/checkconfig.php
jury/check_judgings.php
jury/config.php
jury/contest.php?cmd=add
jury/genpasswds.php
jury/judgehosts.php?cmd=edit&referrer=judgehosts.php
jury/language.php?cmd=add
jury/problem.php?id=fltcmp&cmd=edit
jury/refresh_cache.php
jury/team.php?id=domjudge&cmd=edit
api/'

OFS="$IFS"
IFS='
'

check_html ()
{
	set +e
	url=`perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1")`
	w3url="http://validator.w3.org/check?uri=$url"
	output=`curl -s $w3url |grep 'id="results" class="invalid"'`
	if [ "$output" ] ; then
		echo "HTML validation errors found in '$1'. See: $w3url"
	fi
	set -e
}

for i in $URLS ; do
	url="$LIVEURLPREFIX$i"
	# Special-case plugin interface for user/pass and XML output:
	if [ "${i#plugin/}" != "$i" ]; then
		output=`wget -q --user=$PLUGINUSER --password=$PLUGINPASS -O - "$url" 2>&1`
		if ! echo "$output" | head -n 2 | grep '^<root>' >/dev/null 2>&1 ; then
			printf "Errors found in '$url'\n$output"
		fi
		continue
	fi
	check_html "$url"
done
IFS="$OFS"

exit 0
