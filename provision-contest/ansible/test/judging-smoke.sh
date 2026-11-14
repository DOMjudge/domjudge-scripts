#!/bin/bash
# Runs on the domserver (copied there by e2e.sh). Loads DOMjudge's example
# contest unless present, which also uploads problems with large test data,
# then submits solutions to 'hello' and checks their verdicts: correct ones in
# each default language, a wrong one, and ones exceeding the time and memory
# limits (runguard and its cgroups). With the argument 'kotlin' (the ICPC image
# puts kotlinc in the chroot), Kotlin is enabled and tested as well. Stops early
# on an internal error, e.g. a broken compiler or chroot.
set -euo pipefail
dj=/opt/domjudge
ex=$dj/example_problems/hello/submissions/accepted
pw=$(cat "$dj/etc/initial_admin_password.secret")
api() { curl -fsS --cacert /etc/ssl/certs/domserver.crt -u "admin:$pw" "https://domjudge/api/$1" "${@:2}"; }
json() { python3 -c "import json, sys; d = json.load(sys.stdin); print($1)"; }
first() { for f in "$@"; do [ -e "$f" ] && { echo "$f"; return; }; done; echo "none of: $*" >&2; return 1; }

if ! api 'contests?onlyActive=false' | json '"demo" in [c["id"] for c in d]' | grep -qx True; then
    "$dj/bin/dj_setup_database" -s -u root -S install-pass-fail-examples >/dev/null
fi

if [ "${1:-}" = kotlin ]; then
    # Disabled for submissions in DOMjudge's defaults; a contest enables it.
    mysql domjudge -e "UPDATE language SET allow_submit = 1 WHERE externalid = 'kotlin'"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '#include <stdio.h>\nint main(void) { puts("wrong"); return 0; }\n' > "$tmp/wrong.c"
printf 'int main(void) { for (;;); }\n' > "$tmp/loop.c"
# 3 GiB in 64 MiB steps, above DOMjudge's default memory limit of 2 GiB. The
# cgroup kills it at the limit (exit 137), which DOMjudge reports as RTE or MLE;
# the recorded peak shows that the limit, and not something else, stopped it.
printf '#include <stdlib.h>\n#include <string.h>\nint main(void) { for (int i = 0; i < 48; i++) { char *p = malloc(64 << 20); if (!p) return 1; memset(p, 1, 64 << 20); } return 0; }\n' > "$tmp/memory.c"

# expected verdict, language, file
cases="AC c $ex/test-hello.c
AC cpp $ex/test-hello.c++
AC java $(first "$ex/test-hello.java" "$ex"/*.java)
AC python3 $(first "$ex/test-hello.py" "$ex"/*.py)
WA c $tmp/wrong.c
TLE c $tmp/loop.c
MLE|RTE c $tmp/memory.c"
[ "${1:-}" != kotlin ] || cases+="
AC kotlin $ex/test-hello.kt"

declare -A expected
while read -r verdict lang file; do
    extra=()
    if [ "$lang" = kotlin ]; then
        # Kotlin needs the main class: test-hello.kt compiles to Test_helloKt.
        base=$(basename "$file" .kt)
        extra=(-F "entry_point=$(tr -c '[:alnum:]\n' _ <<<"${base^}")Kt")
    fi
    id=$(api contests/demo/submissions -F problem=hello -F "language=$lang" -F team_id=exteam \
             "${extra[@]}" -F "code[]=@$file" | json 'd["id"]')
    expected[$id]="$verdict $lang"
done <<<"$cases"

pending=("${!expected[@]}")
reason="within 10 minutes"
for _ in $(seq 120); do
    still=()
    for id in "${pending[@]}"; do
        verdict=$(api "contests/demo/judgements?submission_id=$id" |
                  json 'next((j["judgement_type_id"] for j in d if j["end_time"]), "")')
        if [ -z "$verdict" ]; then still+=("$id"); continue; fi
        read -r want lang <<<"${expected[$id]}"
        if [[ $want == *MLE* ]]; then
            peak=$(mysql -N domjudge -e "SELECT jro.metadata FROM judging j
                     JOIN judging_run jr ON jr.judgingid = j.judgingid
                     JOIN judging_run_output jro ON jro.runid = jr.runid
                     WHERE j.submitid = $id AND j.valid = 1" | grep -oE 'memory-bytes: [0-9]+' | grep -oE '[0-9]+$')
            [ "${peak:-0}" -ge $((2 << 30)) ] || verdict="$verdict (peak ${peak:-?} bytes, below the limit)"
        fi
        if [[ $verdict =~ ^($want)$ ]]; then
            echo "ok   $lang submission $id: $verdict"
        else
            echo "FAIL $lang submission $id: expected $want, got $verdict"; touch "$tmp/failed"
        fi
    done
    pending=("${still[@]}")
    [ ${#pending[@]} -gt 0 ] || break
    # An internal error disables the judgehost or language: nothing more happens.
    errors=$(mysql -N domjudge -e "SELECT description FROM internal_error WHERE status = 'open'")
    if [ -n "$errors" ]; then
        echo "FAIL internal error: $errors"; touch "$tmp/failed"; reason="after the internal error"; break
    fi
    sleep 5
done
for id in "${pending[@]}"; do
    echo "FAIL ${expected[$id]#* } submission $id: not judged $reason"; touch "$tmp/failed"
done
[ ! -e "$tmp/failed" ]
