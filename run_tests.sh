#!/bin/sh
#
# Cronjob script to automatically run the following checks:
# - 'make build' works
# - php/shell script syntax checks
# - testsuite tests

set -e

#DEBUG=1

GITURL='https://github.com/DOMjudge/domjudge.git'

if [ "$DEBUG" ]; then
	set -x
else
	export QUIET=1
fi

# Create an export of fresh git master sources:
TEMPDIR=`mktemp -d /tmp/domjudge-run_tests-XXXXXX`
git clone ${QUIET:+-q} "$GITURL" $TEMPDIR/system
cd $TEMPDIR/system

# Test 'make config build docs':
make -k MAINT_CXFLAGS='-O -Wall -fPIE -Wformat -Wformat-security -ansi' \
	maintainer-conf 2>&1 || true
make -k build docs 2>&1

# Test 'make install-{domserver,judgehost,docs}'.
# We need to filter failure to set ownership and permissions of password files.
mkdir $TEMPDIR/install
./configure ${QUIET:+-q} --prefix=$TEMPDIR/install 2>&1 || true
make -k dist build install-domserver install-judgehost install-docs 2>&1 | \
	grep -vE 'install: cannot change owner(ship| and permissions of)' || true

# Run DOMjudge internal tests (remove install-sh script for false positives):
rm install-sh
cd tests
./syntax
./tests ${QUIET:+-q}

[ "$DEBUG" ] || rm -rf $TEMPDIR

exit 0
