#!/bin/bash
# End-to-end checks that change state: run them only on freshly provisioned
# test VMs and restore the snapshot afterwards.
#  - verify.sh passes.
#  - A second run of both playbooks changes nothing, except the intended
#    restart of the judgedaemons.
#  - The judgehost really judges, see judging-smoke.sh.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
export ANSIBLE_NOCOLOR=1 ANSIBLE_FORCE_COLOR=0
indent() { awk '{ print "       " $0 }'; }
fail=0

echo "-- verify.sh"
test/verify.sh || exit 1

expected_changes='Stop judgedaemon service(s) on every possible core
judgedaemon : Enable and start judgedaemon'
for book in domserver judgehost; do
    echo "-- second run of the $book playbook"
    log=$(mktemp --suffix=".$book.log")
    if ! make "$book" >"$log" 2>&1; then
        echo "FAIL $book: playbook failed, see $log"; exit 1
    fi
    changed=$(awk '/^(TASK|RUNNING HANDLER) \[/ { t = $0; sub(/^[^[]*\[/, "", t); sub(/\][^]]*$/, "", t) }
                   /^changed:/ { print t }' "$log" | sort -u | grep -vxF "$expected_changes")
    if [ -n "$changed" ]; then
        echo "FAIL $book: not idempotent, see $log. Changed:"; indent <<<"$changed"; fail=1
    else
        echo "ok   $book: idempotent"; rm "$log"
    fi
done

echo "-- judging (loads the example contest, takes a few minutes)"
log=$(mktemp --suffix=.judging.log)
ansible -i hosts 'domserver[0]' -m script -a "test/judging-smoke.sh {{ 'kotlin' if ICPC_IMAGE else '' }}" >"$log" 2>&1
status=$?
results=$(grep -oE '(ok|FAIL) +([a-z0-9]+ submission [0-9]+|internal error): [^"\\]*' "$log" | sort -u)
[ -z "$results" ] || indent <<<"$results"
if [ $status -eq 0 ] && [ -n "$results" ] && ! grep -q '^FAIL' <<<"$results"; then
    echo "ok   judging"; rm "$log"
else
    echo "FAIL judging, see $log"; fail=1
fi
exit $fail
