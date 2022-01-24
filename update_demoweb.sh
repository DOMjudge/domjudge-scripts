#!/bin/sh
# Script to update the DOMjudge demo webinterface
# at:    https://www.domjudge.org/demoweb/

# shellcheck disable=SC2086 # globally for MYSQLOPTS twice

set -e

MYSQLOPTS=''
DBNAME='domjudge_demo2018'

cd ~/demoweb

# Update the code:
git pull -q --rebase --autostash >/dev/null 2>&1

# Rebuild in-place to also make configuration updates visible:
make QUIET=1 maintainer-clean
make QUIET=1 MAINT_CXFLAGS='-g -O2 -Wall -fPIE -Wformat -Wformat-security' \
	inplace-conf >/dev/null 2>&1 || true
make QUIET=1 inplace-install docs >/dev/null 2>&1
composer auto-scripts >/dev/null 2>&1

# Reset database to known good state:
mysql $MYSQLOPTS "$DBNAME" < domjudge_demo_remove.sql
mysql $MYSQLOPTS "$DBNAME" < domjudge_demo.sql

# Upgrade the database to the latest structure
./sql/dj_setup_database -q upgrade

# Reset apache alias to correct state
sed -i 's|Alias /domjudge|Alias /demoweb|g' etc/apache.conf

# Warmup the cache for our first visitor
./webapp/bin/console -q cache:clear
./webapp/bin/console -q cache:warmup
