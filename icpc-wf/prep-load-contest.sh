#!/bin/bash

# Run this inside a CDP contest 'config' directory to prepare things
# to be imported into DOMjudge.

set -e

if [ ! -r contest.yaml ] || [ ! -r problemset.yaml ]; then
	echo "No 'contest.yaml' or 'problemset.yaml' found."
	exit 1
fi

(
	cat contest.yaml
	echo
	cat problemset.yaml
) > contest-all.yaml

CONTESTNAME=$( grep '^name:'       contest.yaml | sed 's/^name:[[:space:]]*//')
CONTESTSTART=$(grep '^start-time:' contest.yaml | sed 's/^start-time:[[:space:]]*//')

STARTDELAY=$(expr $(date -d "$CONTESTSTART" +%s) - $(date +%s))

if [ -r system.yaml ]; then
	echo >> contest-all.yaml
	cat system.yaml >> contest-all.yaml
fi

NPROBLEMS=0
for i in * ; do
	if [ -d "$i" ]; then
		((NPROBLEMS++)) || true
		( cd "$i" && zip -rq "../$i.zip" . )
	fi
done

echo "Found contest '$CONTESTNAME' with $NPROBLEMS problems,"
echo "scheduled to start in $((STARTDELAY / 3600)):$(( (STARTDELAY / 60) % 60)) hours."

