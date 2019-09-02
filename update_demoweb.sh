#!/bin/sh
# Script to update the DOMjudge demo webinterface
# at:    https://www.domjudge.org/demoweb/

set -e

MYSQLOPTS=''
DBNAME='domjudge_demo2018'

cd ~/demoweb

# Update the code:
git pull -q --rebase --autostash >/dev/null 2>&1

# Rebuild in-place to also make configuration updates visible:
make QUIET=1 maintainer-clean
make QUIET=1 MAINT_CXFLAGS='-g -O2 -Wall -fPIE -Wformat -Wformat-security' \
	maintainer-conf || true
make QUIET= maintainer-install >/dev/null 2>&1
composer auto-scripts >/dev/null 2>&1

# Reset database to known good state:
mysql $MYSQLOPTS "$DBNAME" < domjudge_demo_remove.sql
mysql $MYSQLOPTS "$DBNAME" < domjudge_demo.sql

# Upgrade the database to the latest structure
DBUSER=$(cat ~/.my.cnf  | grep user | grep -oP '\w+$')
DBPASS=$(cat ~/.my.cnf  | grep password | grep -oP '\w+$')
./sql/dj_setup_database -q -u $DBUSER -p $DBPASS upgrade
