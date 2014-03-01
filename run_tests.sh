#!/bin/sh
#
# Cronjob script to automatically run the following checks:
# - 'make build' works
# - php/shell script syntax checks
# - testsuite tests

set -e

#DEBUG=1

GITURL='https://github.com/DOMjudge/domjudge.git'

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
TEMPDIR=`mktemp -d /tmp/domjudge-run_tests-XXXXXX`
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

[ "$DEBUG" ] || rm -rf $TEMPDIR

exit 0
