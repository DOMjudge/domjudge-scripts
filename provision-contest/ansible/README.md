# Ansible code for DOMjudge at the ICPC World Finals

The ansible code under this directory is used to configure running
DOMjudge at the ICPC World Finals, both as primary and shadow CCS.
This ansible code can deploy four different types of machines:

* admin: used by DOMjudge staff to work on and access the other
  machines from. Also has a local DOMjudge install with domserver and
  judgedaemon, running in DEV mode.
* domserver: machines running the DOMjudge web server and
  MySQL/MariaDB database. By default we have two: a primary and a
  backup.
* judgehost: machines running one judgedaemon each. We use as many as
  necessary and depending on machines available. These should be
  identical to each other and preferably also to the team machines.
* scoreboard: for some contests (different from the world finals) we
  use a mirror of the scoreboard to not overload the server with
  requests from viewers.
* cds: machine which hosts the [CDS](https://tools.icpc.global/cds/), if you use
  this you should also look at the `presclient` & `presadmin` playbooks to setup
  machines which can present those presentations.
* grafana: monitoring machine to observe the performance of both the DOMjudge instance
  and the webservers, optionally we monitor the participant machines in case of suspected
  hardware issues (loose PSU, CPU performance etc.)

## Code organization

The ansible tasks are split up in
[roles](https://docs.ansible.com/ansible/latest/user_guide/playbooks_reuse_roles.html)
to prevent duplication.

Global and group variables are stored under `group_vars`. The file
`group_vars/all/secret.yml.example` should be copied to
`group_vars/all/secret.yml` and then all variables should be set
and/or modified as required. The script `generate_passwords.py` can be used
to prefill some of those passwords with a xkcd style password. In `secret.yml.example`
the passwords can be listed as either `{some-password}` or `some-password` the `{}` is *not*
required but only used as anchor for the script, so adding the `{}` would make it part of the
password.

There are a few places where additional files should/can be added:
* SSH public/private keys under `roles/ssh/files/`.
* SSL certificates and keys under `roles/ssl/files/`.
* Machine/group specific local packages under `roles/base_packages/files/install-*/`.
* Judgehost chroot local packages under `roles/judgedaemon/files/install-chroot/`.
* The vendor dependencies under `roles/domjudge_checkout/files/vendor.tgz`.
* Machine/group specific docker containers under `roles/docker/files/containers-*/`.

## TODO

* Adding entries to `/etc/hosts` from the local inventory is messy and
  the current tasks keep reporting as "changed" after each run.
* The `grafana` playbook still needs to be converted to using roles.
* Improve/document some variables like `WF_RESTRICTED_NETWORK`.
