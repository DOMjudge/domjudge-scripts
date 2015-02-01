#!/bin/sh
#
# Cronjob script to automatically run HTML validation of webpages
# on an live, publicly accessible DOMjudge installation.

set -e

#DEBUG=1

LIVESYSTEMDIR=~/system
LIVEURLPREFIX='http://www.domjudge.org/domjudge/'

# Optionally specify a non-priveleged jury user to check the jury web
# pages without admin permissions:
#WEB_USER=jury
#WEB_PASS=passwordhere

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

TEMPDIR=`mktemp -d /tmp/domjudge-html_validation-XXXXXX`

cd ~

# Validate DOMjudge webpages running from uptodate git checkout
# (we cannot use a fresh checkout due to missing website config)
cd $LIVESYSTEMDIR && git stash -q && git pull -q && git stash pop -q

URLS='
.
public/
public/team.php?id=2
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
jury/contest.php?id=2
jury/index.php
jury/judgehosts.php
jury/judgehost.php?id=judgehost1
jury/judgehost_restrictions.php
jury/judgehost_restriction.php?id=1
jury/language.php?id=c
jury/languages.php
jury/problems.php
jury/problem.php?id=7
jury/scoreboard.php
jury/scoreboard.php?country[]=NLD
jury/show_source.php?id=1
jury/edit_source.php?id=1&rank=0
jury/submission.php?id=1
jury/submission.php?id=91
jury/submission.php?id=94
jury/show_source.php?id=3
jury/submissions.php?view[0]
jury/submissions.php?view[1]
jury/submissions.php?view[2]
jury/team_affiliations.php
jury/team_affiliation.php?id=1
jury/team_categories.php
jury/team_category.php?id=1
jury/team.php?id=2
jury/teams.php
jury/users.php
jury/user.php?id=1
jury/testcase.php?probid=10
jury/executables.php
jury/executable.php?id=c
jury/auditlog.php
jury/checkconfig.php
jury/check_judgings.php
jury/config.php
jury/contest.php?cmd=add
jury/genpasswds.php
jury/judgehosts.php?cmd=edit&referrer=judgehosts.php
jury/judgehost_restriction.php?cmd=add
jury/language.php?cmd=add
jury/problem.php?id=7&cmd=edit
jury/refresh_cache.php
jury/team.php?id=2&cmd=edit
api/'

OFS="$IFS"
IFS='
'

NUNCHECKED=0

check_html ()
{
	set +e
	url=`perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1")`
	w3url="http://validator.w3.org/check?uri=$url"
	TEMP=`mktemp $TEMPDIR/validate_XXXXXX.html`
	curl -s ${WEB_USER:+-u$WEB_USER:$WEB_PASS} $w3url > $TEMP
	if grep 'class="msg">External Checker not available' $TEMP >/dev/null 2>&1 ; then
		NUNCHECKED=$((NUNCHECKED+1))
	elif grep 'id="results" class="invalid"' $TEMP >/dev/null 2>&1 ; then
		echo "<a href=\"$w3url\">HTML validation errors found</a> in" \
		     "<a href=\"$1\">$1</a>.<br />"
	fi
	set -e
}

for i in $URLS ; do
	url="$LIVEURLPREFIX$i"
	check_html "$url"
done
IFS="$OFS"

if [ "$NUNCHECKED" -ge 1 ]; then
	echo "<p><b>Unable to validate $NUNCHECKED pages.</b></p>"
fi

[ "$DEBUG" ] || rm -rf $TEMPDIR

exit 0
