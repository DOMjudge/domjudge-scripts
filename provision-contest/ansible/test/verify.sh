#!/bin/bash
# Post-run assertions against the test VMs: checks the resulting state, not
# only that ansible exited 0. Read-only. Runs every check through ansible on
# the inventory groups, so it covers all hosts listed in `hosts`.
# The single-quoted commands are expanded on the hosts, not here:
# shellcheck disable=SC2016
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
export ANSIBLE_NOCOLOR=1

# ansible succeeds without doing anything if there are no hosts.
[ -e hosts ] && [ -e group_vars/onprem/all.yml ] ||
    { echo "No inventory or group_vars: run test/bootstrap.sh first." >&2; exit 1; }
for group in domserver judgehost; do
    ansible -i hosts "$group" --list-hosts 2>/dev/null | grep -q 'hosts ([1-9]' ||
        { echo "No hosts in group '$group' of the inventory." >&2; exit 1; }
done

fail=0
check() { # description host-pattern shell-command (may use ansible variables)
    local out
    if out=$(ansible -i hosts "$2" -m shell -a "$3" 2>&1); then
        echo "ok   $1"
    else
        echo "FAIL $1"; awk '{ print "       " $0 }' <<<"$out"; fail=1
    fi
}

# The domserver is checked on its own address: the ICPC image has a separate
# nginx site on 127.0.0.1.
api='curl -fsS --cacert /etc/ssl/certs/domserver.crt --resolve domjudge:443:{{ ansible_host }}'

{
read -r -d '' mariadb_config <<'EOF'
for v in max_allowed_packet max_connections open_files_limit; do
    want=$(my_print_defaults --mysqld | sed -n "s/^--$v=//p" | tail -n 1 | tr '[:lower:]' '[:upper:]')
    [ -n "$want" ] && [ "$(mysql -N -e "SELECT @@GLOBAL.$v")" -ge "$(numfmt --from=iec "$want")" ] || exit 1
done
EOF
read -r -d '' fpm_config <<'EOF'
pool=$(ls /etc/php/*/fpm/pool.d/domjudge.conf | head -n 1)
for setting in "pm.max_children = {{ PHP_FPM_MAX_CHILDREN }}" "pm.max_requests = {{ PHP_FPM_MAX_REQUESTS }}" \
        "php_admin_value[memory_limit] = {{ PHP_MEMORY_LIMIT }}" "php_admin_value[upload_max_filesize] = {{ PHP_UPLOAD_MAX_FILESIZE }}" \
        "php_admin_value[post_max_size] = {{ PHP_POST_MAX_SIZE }}" "php_admin_value[max_file_uploads] = {{ PHP_MAX_FILE_UPLOADS }}"; do
    grep -qxF "$setting" "$pool" || exit 1
done
# Started after the pool was last written, so these settings are in effect.
pid=$(systemctl show -p MainPID --value "$(systemctl list-units --no-legend --plain 'php*-fpm.service' | cut -d' ' -f1)")
[ "$(stat -L -c %Y "$pool")" -le "$(date -d "$(ps -o lstart= -p "$pid")" +%s)" ] || exit 1
"$(ls /usr/sbin/php-fpm* | head -n 1)" -m | grep -qx intl
EOF
read -r -d '' judgedaemons <<'EOF'
units=$(systemctl list-units --all --no-legend --plain 'domjudge-judgedaemon@*' | cut -d' ' -f1)
[ -n "$units" ] || exit 1
for u in $units; do systemctl is-active --quiet "$u" || exit 1; done
EOF
read -r -d '' registered <<'EOF'
cores=$(systemctl list-units --all --no-legend --plain 'domjudge-judgedaemon@*' | sed -n 's/^domjudge-judgedaemon@\([0-9]*\)\.service.*/\1/p')
curl -fsS -u 'admin:{{ ADMIN_PASSWORD }}' https://domjudge/api/judgehosts | python3 -c '
import json, sys, time
hosts = {h["hostname"]: h for h in json.load(sys.stdin)}
want = ["{{ inventory_hostname }}-" + core for core in sys.argv[1:]]
sys.exit(not want or not all(n in hosts and hosts[n]["enabled"] and hosts[n]["polltime"]
                             and time.time() - float(hosts[n]["polltime"]) < 120 for n in want))' $cores
EOF
} || true

check "domserver: nginx active"      domserver 'systemctl is-active --quiet nginx'
check "domserver: php-fpm active"    domserver "systemctl list-units --state=active --no-legend 'php*-fpm.service' | grep -q ."
check "domserver: mariadb active"    domserver 'systemctl is-active --quiet mariadb'
# The values in effect, not the files: a missed restart leaves the defaults.
check "domserver: mariadb runs with its configuration" domserver "$mariadb_config"
check "domserver: php-fpm runs with its configuration" domserver "$fpm_config"
check "domserver: DB configured"     domserver '/opt/domjudge/bin/dj_setup_database -s -u root status'
check "domserver: API over HTTPS"    domserver "$api https://domjudge/api/info"
check "domserver: dev mode disabled" domserver 'f=/opt/domjudge/webapp/.env.local; test -f $f && ! grep -q "^APP_ENV=dev" $f'
check "traditional sudo is default"  'domserver:judgehost' 'sudo --version | grep -q "^Sudo version "'

check "judgehost: cores isolated, cgroup memory" judgehost '[ -n "$(cat /sys/devices/system/cpu/isolated)" ] && grep -q cgroup_enable=memory /proc/cmdline'
check "judgehost: chroot built"              judgehost 'test -d /chroot/domjudge/usr'
check "judgehost: all judgedaemons active"   judgehost "$judgedaemons"
check "judgehost: domjudge resolves to the domserver" judgehost '[ "$(getent hosts domjudge | cut -d" " -f1)" = "{{ DOMSERVER_IP }}" ]'
check "judgehost: reaches domserver over TLS" judgehost 'curl -fsS https://domjudge/api/info'
check "judgehost: every judgedaemon registered, enabled, polling" judgehost "$registered"

if [ "$(sed -n 's/^GRAPHICAL: *//p' group_vars/onprem/all.yml)" = true ]; then
    check "desktop: graphical session of user domjudge" 'domserver:judgehost' \
        "loginctl list-sessions --no-legend | awk '\$3 == \"domjudge\" && \$4 ~ /^seat/ { found = 1 } END { exit !found }'"
    check "desktop: autostart entries"       'domserver:judgehost' 'ls /home/domjudge/.config/autostart/*.desktop'
    # domlogo needs Python libraries supplied by hand, see roles/domlogo/files/README.md.
    if compgen -G 'roles/domlogo/files/lib/python3*/*' >/dev/null; then
        check "desktop: domlogo active"      judgehost 'systemctl is-active --quiet domlogo'
    else
        echo "skip desktop: domlogo active (no libraries in roles/domlogo/files/lib)"
    fi
fi

exit $fail
