#!/bin/sh -e

# Run a Coverity scan on the local directory (which must be in a
# configured DOMjudge source-tree root) and submit it. With option
# '-c' create a clean checkout and run 'make maintainer-conf' to
# prepare it to submit from.

# The following variables must be set manually:

TOKEN=SECRET_PROJECT_TOKEN

EMAIL=yourname@example.com

COVTOOL=/path/to/cov-analysis-linux64-XX

# This may be adjusted to point e.g. to a local URL:
GITURL="https://github.com/DOMjudge/domjudge"

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
	TEMPDIR=`mktemp -d /tmp/domjudge-cov-scan-XXXXXX`
	git clone $QUIETOPT "$GITURL" $TEMPDIR
	cd $TEMPDIR
	make $QUIETMAKE maintainer-conf
fi

if [ ! -r paths.mk ]; then
	echo "Cannot find 'paths.mk', run in the root of a configured DOMjudge source tree!"
	exit 1
fi

VERSION=`  grep '^VERSION ='   paths.mk | sed 's/^VERSION = *//'`
PUBLISHED=`grep '^PUBLISHED =' paths.mk | sed 's/^PUBLISHED = *//'`

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

if [ -n "$QUIET" ]; then
	cov-build --dir cov-int make $QUIETMAKE build build-scripts 2>&1 | \
		grep -vE '(^Coverity Build Capture|^Internal version numbers:|^ *$|compilation units \(100%\)|^The cov-build utility completed successfully.)' || true
else
	cov-build --dir cov-int make $QUIETMAKE build build-scripts
fi

ARCHIVE=domjudge-scan.tar.xz

[ -n "QUIET" ] || echo "Compressing scan directory 'cov-int' into '$ARCHIVE'..."

tar caf "$ARCHIVE" cov-int

[ -n "QUIET" ] || echo "Submitting '$VERSION' '$DESC'"

TMP=`mktemp --tmpdir curl-cov-submit-XXXXXX.html`

curl --form token="$TOKEN" --form email="$EMAIL" --form file=@"$ARCHIVE" \
     --form version="$VERSION" --form description="$VERSION - $DESC" \
     -o $TMP ${QUIET:+-s} https://scan.coverity.com/builds?project=DOMjudge

cat $TMP

rm -f $TMP

if [ -n "$NEWCHECKOUT" ]; then
	rm -rf "$TEMPDIR"
fi

exit 0
