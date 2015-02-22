#!/bin/sh -e

# Run a Coverity scan on the local directory (which must be in a
# checktestdata source-tree root) and submit it.

# The following variables must be set manually:

TOKEN=SECRET_PROJECT_TOKEN

EMAIL=yourname@example.com

COVTOOL=/path/to/cov-analysis-linux64-XX


if [ ! -r config.mk ]; then
	echo "Cannot find 'config.mk', run in the root of a"
	echo "configured checktestdata source tree!"
	exit 1
fi

git_dirty()
{
	git diff --quiet --exit-code || echo -n '*'
}
git_branch()
{
	git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/"
}
git_commit()
{
	git rev-parse HEAD | cut -c -12
}

VERSION=`grep '^VERSION =' config.mk | sed 's/^VERSION = *//'`

DESC="git: $(git_branch)$(git_dirty) $(git_commit)"

export PATH="$PATH:$COVTOOL/bin"

make dist

cov-build --dir cov-int make build

ARCHIVE=checktestdata-scan.tar.xz

echo "Compressing scan directory 'cov-int' into '$ARCHIVE'..."

tar caf "$ARCHIVE" cov-int

echo "Submitting '$VERSION' '$DESC'"

TMP=`mktemp --tmpdir curl-cov-submit-XXXXXX.html`

curl --form token="$TOKEN" --form email="$EMAIL" --form file=@"$ARCHIVE" \
     --form version="$VERSION" --form description="$VERSION - $DESC" \
     -o $TMP https://scan.coverity.com/builds?project=Checktestdata

cat $TMP

rm -f $TMP

exit 0
