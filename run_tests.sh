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
LIVEURLPREFIX='http://domjudge.a-eskwadraat.nl/domjudge/'
GITURL='git://a-eskwadraat.nl/git/domjudge.git'

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
		$@ > /dev/null 2>&1
	fi
}

# Create an export of fresh git master sources:
TEMPDIR=`mktemp -d /tmp/domjudge.XXXXXX`
git clone -q "$GITURL" $TEMPDIR/system
cd $TEMPDIR/system

# Test 'make config build docs':
make -k QUIET=1 CONFIGURE_FLAGS='--disable-submitclient' \
	MAINT_CXFLAGS='-O -Wall -fPIE -Wformat -Wformat-security -ansi' \
	maintainer-conf 2>&1 | grep -v "^/usr/share/aclocal/" || true
make -k QUIET=1 build docs 2>&1

# Run DOMjudge internal tests (remove install-sh script for false positives):
rm install-sh
cd tests
./syntax
./tests -q

cd ~

[ "$DEBUG" ] || rm -rf $TEMPDIR


# Validate DOMjudge webpages running from uptodate git checkout
# (we cannot use a fresh checkout due to missing website config)
cd $LIVESYSTEMDIR && git pull -q

URLS='
.
plugin/scoreboard.php
plugin/event.php?fromid=1&toid=50
public
public/team.php?id=domjudge
team
team/clarification.php
team/clarification.php?id=137
team/submission_details.php?id=129
jury
jury/auditlog.php
jury/balloons.php
jury/checkconfig.php
jury/clarification.php
jury/clarification.php?id=107
jury/clarifications.php
jury/contests.php
jury/contest.php?cmd=add
jury/check_judgings.php
jury/genpasswds.php
jury/index.php
jury/judgehosts.php
jury/judgehosts.php?cmd=edit&referrer=judgehosts.php
jury/judgehost.php?id=judgehost1
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
jury/show_source.php?id=3
jury/submissions.php?view[0]
jury/submissions.php?view[1]
jury/submissions.php?view[2]
jury/team_affiliations.php
jury/team_affiliation.php?id=UU
jury/team_categories.php
jury/team_category.php?id=1
jury/team.php?id=domjudge
jury/team.php?id=domjudge&cmd=edit
jury/teams.php
jury/testcase.php?probid=hello'

OFS="$IFS"
IFS='
'

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
	output=`wget -q --user=$JUDGEUSER --password=$JUDGEPASS -O - "$url" 2>&1 | \
		tidy -q -e -utf8 --new-blocklevel-tags nav 2>&1 1>/dev/null | \
		grep -vE 'Warning: (<nav> is not|<table> lacks|<input> attribute "type" .* value "(color|number)"|trimming empty|.* proprietary attribute|missing </pre> before <ol>|inserting implicit <pre>)' || true`
	if [ "$output" ] ; then
		echo "Errors found in '$url'
$output"
	fi
done
IFS="$OFS"

exit 0
