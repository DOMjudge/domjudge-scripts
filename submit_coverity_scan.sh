#!/bin/sh -eu

# Run a Coverity scan on the local directory (which must be in a
# configured DOMjudge or Checktestdata source-tree root) and submit
# it, using 'make coverity-build'. Files 'cov-submit-data*.sh' are
# sourced to read variables PROJECT, EMAIL, TOKEN, COVTOOL and
# optionally DESC, which are used for submission.
#
# The following options are available:
#
# -c FILE      Also read variables from FILE. This can be specified
#              multiple times; these variables can be overriden later.
#              If option is not specified this defaults to reading
#              'cov-submit-data*.sh' from the current directory.
# -d           Enable verbose debugging output.
# -n INTERVAL  Set e.g. to 'X days' to only submit if there are
#              commits more recent than that.
# -u URL       Create a clean checkout from the Git URL argument and
#              run 'make coverity-conf' to prepare it to submit from.
# -q           Quiet, suppress feedback.

ARCHIVE=coverity-scan.tar.xz

READCONFIG=''
DEBUG=''
NEWERTHAN=''
GITURL=''
QUIET=''
QUIETOPT=''
QUIETMAKE=''

# Parse command-line options:
while getopts ':c:dn:u:q' OPT ; do
	case "$OPT" in
		c)
			READCONFIG=1
			if [ ! -r "$OPTARG" ]; then
				echo "Error: cannot read '$OPTARG'."
				exit 1
			fi
			# shellcheck source=/dev/null
			. "$OPTARG"
			;;
		d) DEBUG=1 ;;
		n) NEWERTHAN=$OPTARG ;;
		u) GITURL=$OPTARG ;;
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

if [ -n "$DEBUG" ]; then
	echo "Debugging enabled."
	set -x
fi

# Read variables now, since they may specify COVTOOL, GITURL and NEWERTHAN:
if [ -z "$READCONFIG" ]; then
	for i in ./cov-submit-data*.sh ; do
		# Check if the file exists in case the globbing returned nothing:
		[ -r "$i" ] || continue
		# shellcheck source=/dev/null
		. "$i"
	done
fi

export PATH="$PATH:$COVTOOL/bin"

git_dirty()
{
	git diff --quiet --exit-code || printf '*'
}
git_branch()
{
	git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/"
}
git_commit()
{
	git rev-parse HEAD | cut -c -12
}

quietfilter()
{
	if [ "$QUIET" ]; then
		grep -vE '(^Coverity Build Capture|^Internal version numbers:|^[[:space:]]*$|compilation units \(100%\)|PHP compilation units \([8-9][0-9]%\)|(JavaScript|Python) compilation units \(9[0-9]%\)|^Looking for translation units|^The cov-build utility completed successfully\.|^Build successfully submitted\.|^\[STATUS\] |^\*+$|^\|[0-9-]+\|$|^\[WARNING\] (Path .* looks like an idir\.|No source file matches in filesystem capture search directory:|Filesystem capture was enabled but yielded no source file matches\.))' || true
	else
		cat
	fi
}

if [ -n "$GITURL" ]; then
	TEMPDIR=$(mktemp -d /tmp/cov-scan-XXXXXX)
	git clone $QUIETOPT "$GITURL" "$TEMPDIR"
	cd "$TEMPDIR"
	make $QUIETMAKE coverity-conf
fi

if [ -n "$NEWERTHAN" ]; then
	if [ -z "$(git log --since="$(date -d "now - $NEWERTHAN")")" ]; then
		[ -n "$QUIET" ] || echo "No new commits in the last $NEWERTHAN, aborting."
		exit 0
	fi
fi

COVOPTS='--dir cov-int --fs-capture-search ./'
# shellcheck disable=SC2086
cov-build $COVOPTS make $QUIETMAKE coverity-build 2>&1 | quietfilter

VERSION=$(grep '^VERSION' paths.mk | sed 's/.*= *//')
DESC="git: $(git_branch)$(git_dirty) $(git_commit)"
# Read variables again for files produced by coverity-build:
for i in ./cov-submit-data*.sh ; do
	# Check if the file exists in case the globbing returned nothing:
	[ -r "$i" ] || continue
	# shellcheck source=/dev/null
	. "$i"
done

# Check if we have all submission data:
if [ -z "$PROJECT" ] || [ -z "$EMAIL" ] || [ -z "$TOKEN" ]; then
	echo "Error: missing submission data: PROJECT, EMAIL or TOKEN not specified."
	echo "PROJECT=$PROJECT"
	echo "EMAIL=$EMAIL"
	echo "TOKEN=$TOKEN"
	exit 1
fi

[ -n "$QUIET" ] || echo "Compressing scan directory 'cov-int' into '$ARCHIVE'..."

tar caf "$ARCHIVE" cov-int

[ -n "$QUIET" ] || echo "Submitting '$VERSION' '$DESC'"

TMP=$(mktemp --tmpdir curl-cov-submit-XXXXXX.html)

${DEBUG:+echo} \
curl --form token="$TOKEN" --form email="$EMAIL" --form file=@"$ARCHIVE" \
     --form version="$VERSION" --form description="$VERSION - $DESC" \
     -o "$TMP" ${QUIET:+-s} https://scan.coverity.com/builds?project="$PROJECT" 2>&1 \
	| quietfilter

[ -n "$QUIET" ] || grep -vE '^[[:space:]]*$' "$TMP"

rm -f "$TMP"

if [ -n "$GITURL" ] && [ -z "$DEBUG" ]; then
	rm -rf "$TEMPDIR"
fi

exit 0
