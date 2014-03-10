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

# Test 'make install-{domserver,judgehost,docs}'.
# To make this work, we need to disable the root check and filter
# failure to set ownership and permissions of installed files.
mkdir $TEMPDIR/install
sed -i '/: check-root/d' Makefile
QUIET=1 ./configure -q --enable-cgroups --prefix=$TEMPDIR/install 2>&1 || true
make -k QUIET=1 build install-domserver install-judgehost install-docs 2>&1 | \
	grep -vE 'install: cannot change owner(ship| and permissions of)' || true

# Run DOMjudge internal tests (remove install-sh script for false positives):
rm install-sh
cd tests
./syntax
./tests -q

[ "$DEBUG" ] || rm -rf $TEMPDIR

exit 0
