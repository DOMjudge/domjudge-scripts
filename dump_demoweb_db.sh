#!/bin/sh
# Script to dump the DOMjudge demo web DB to ~/demoweb/domjudge_
# at:    https://www.domjudge.org/demoweb/

set -e

DBNAME='domjudge_demo2018'
DUMPFILE=~/demoweb/${DBNAME}-$(date +%F).sql

mysqldump $DBNAME | process-mysqldump > "$DUMPFILE"

cat <<EOF

Dumped demoweb DB in '$DUMPFILE'.

Don't forget to diff the contents and update
the ~/demoweb/domjudge_demo.sql symlink.
EOF
