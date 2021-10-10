#!/bin/sh
#
# Script to generate a snapshot package and then use that to test if
# various Makefile targets work as expected.

set -e

GITURL="https://github.com/DOMjudge/domjudge.git"

#DEBUG=1

[ "$DEBUG" ] && set -x
quiet()
{
	if [ "$DEBUG" ]; then
		$@
	else
		$@ > /dev/null 2>&1
	fi
}

TEMPDIR=`mktemp -d /tmp/domjudge-check_build-XXXXXX`
cd $TEMPDIR

git clone -q --no-checkout --depth 1 "$GITURL" dj-clone

( cd dj-clone && git archive --prefix=domjudge/ --format=tar refs/heads/main ) | tar x

# Add released tag for revision information:
sed -i "s/PUBLISHED =.*/PUBLISHED = `date +%Y-%m-%d`/" domjudge/paths.mk.in

quiet make -C domjudge dist

# Remove date output from generated file tags to make diffs cleaner:
sed -i 's/ on `date`//' domjudge/paths.mk.in

cp -a domjudge configured

( cd configured && ./configure )

# Test if all the "build-like" targets work independently:
for i in all build domserver judgehost docs ; do
	cp -a configured $i
	( cd $i && make $i )
done

# Test cleanup targets:
for i in clean distclean ; do
	cp -a all $i
	( cd $i && make $i )
done

# Check that ./configure && make all && make distclean returns
# to original state:
diff -r -u2 domjudge distclean

if [ "$DEBUG" ]; then
	echo "Generated files left in $TEMPDIR"
else
	rm -rf $TEMPDIR
fi

exit 0
