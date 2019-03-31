#!/bin/bash -e

jid=$1

judgehost=$(http https://domjudge/api/contests/test1/judgements/${jid} | grep judgehost | cut -d\" -f4 | cut -d- -f1,2)

dest="/tmp/j${jid}/"
mkdir -p "$dest"
scp -r $judgehost:/home/domjudge/domjudge/output/judgings/${judgehost}-0/endpoint-default/c*j${jid}/* "$dest" &> /dev/null

echo "Succesfully copied package to $dest"
