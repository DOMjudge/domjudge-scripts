#!/bin/sh -e

# Run a Coverity scan on the local directory (which must be in a
# checktestdata source-tree root) and submit it. With option
# '-c' create a clean checkout and submit from 'release' branch.

# The following variables must be set manually:

TOKEN=SECRET_PROJECT_TOKEN

EMAIL=yourname@example.com

COVTOOL=/path/to/cov-analysis-linux64-XX

# This may be adjusted to point e.g. to a local URL:
GITURL="https://github.com/DOMjudge/checktestdata"

# Parse command-line options:
while getopts ':cq' OPT ; do
	case "$OPT" in
		c) NEWCHECKOUT=1 ;;
		q) QUIET=1; QUIETOPT="-q" QUIETMAKE="QUIET=1" ;;
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

if [ -n "$NEWCHECKOUT" ]; then
	TEMPDIR=`mktemp -d /tmp/checktestdata-cov-scan-XXXXXX`
	git clone $QUIETOPT "$GITURL" $TEMPDIR
	cd $TEMPDIR
	git checkout $QUIETOPT release
	./bootstrap $QUIETOPT
fi

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

export PATH="$PATH:$COVTOOL/bin"

make $QUIETMAKE dist

if [ -n "$QUIET" ]; then
	cov-build --dir cov-int make $QUIETMAKE build 2>&1 | \
		grep -vE '(^Coverity Build Capture|^Internal version numbers:|^ *$|compilation units \(100%\)|^The cov-build utility completed successfully.)' || true
else
	cov-build --dir cov-int make $QUIETMAKE build
fi

VERSION=`grep '^VERSION =' config.mk | sed 's/^VERSION = *//'`

DESC="git: $(git_branch)$(git_dirty) $(git_commit)"

ARCHIVE=checktestdata-scan.tar.xz

[ -n "QUIET" ] || echo "Compressing scan directory 'cov-int' into '$ARCHIVE'..."

tar caf "$ARCHIVE" cov-int

[ -n "QUIET" ] || echo "Submitting '$VERSION' '$DESC'"

TMP=`mktemp --tmpdir curl-cov-submit-XXXXXX.html`

curl --form token="$TOKEN" --form email="$EMAIL" --form file=@"$ARCHIVE" \
     --form version="$VERSION" --form description="$VERSION - $DESC" \
     -o $TMP ${QUIET:+-s} https://scan.coverity.com/builds?project=Checktestdata

cat $TMP

rm -f $TMP

if [ -n "$NEWCHECKOUT" ]; then
	rm -rf "$TEMPDIR"
fi

exit 0
