#!/bin/sh -e

# Run a Coverity scan on the local directory (which must be in a
# DOMjudge source-tree root) and submit it.

# The following variables must be set manually:

TOKEN=SECRET_PROJECT_TOKEN

EMAIL=yourname@example.com

COVTOOL=/path/to/cov-analysis-linux64-XX


if [ ! -r paths.mk ]; then
	echo "Cannot find 'paths.mk', run in the root of a configured DOMjudge source tree!"
	exit 1
fi

VERSION=`  grep '^VERSION ='   paths.mk | sed 's/^VERSION = *//'`
PUBLISHED=`grep '^PUBLISHED =' paths.mk | sed 's/^PUBLISHED = *//'`

git_dirty()
{
	[ "$(git status 2> /dev/null | tail -n1)" != "nothing to commit (working directory clean)" ] && echo -n '*'
}
git_branch()
{
	git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/"
}
git_commit()
{
	git rev-parse HEAD | cut -c -12
}

if [ "$PUBLISHED" = release ]; then
	DESC="release"
elif [ -n "$PUBLISHED" ]; then
	DESC="snapshot $PUBLISHED"
elif [ -d .git ]; then
	DESC="git: $(git_branch)$(git_dirty) $(git_commit)"
else
	DESC="unknown source on `date`"
fi

export PATH="$PATH:$COVTOOL/bin"

cov-build --dir cov-int make build build-scripts

ARCHIVE=domjudge-scan.tar.xz

echo "Compressing scan directory 'cov-int' into '$ARCHIVE'..."

tar caf "$ARCHIVE" cov-int

echo "Submitting '$VERSION' '$DESC'"

TMP=`mktemp --tmpdir curl-cov-submit-XXXXXX.html`

curl --form project=DOMjudge --form token="$TOKEN" \
     --form email="$EMAIL" --form file=@"$ARCHIVE" \
     --form version="$VERSION" --form description="$VERSION - $DESC" \
     -o $TMP https://scan.coverity.com/builds?project=DOMjudge

cat $TMP

rm -f $TMP

exit 0
