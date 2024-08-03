default:
	@echo "No default target available, run one of:"
	@echo
	@echo " - make domserver"
	@echo " - make judgehost"
	@echo " - make admin"
	@echo " - make grafana"
	@echo " - make cds"
	@echo " - make presclient"
	@echo " - make presadmin"
	@echo " - make scoreboard"
	@echo " - make autoanalyst"

VENDORTGZ=roles/domjudge_checkout/files/vendor.tgz
SSHKEY=roles/ssh/files/id_ed25519
SSL_DOMSERVER=roles/ssl/files/domserver
SSL_DOMSERVER_FILES=$(addprefix $(SSL_DOMSERVER),.key .crt)
SSL_NODEEXPORT=roles/prometheus_target_all/files/node_exporter
SSL_NODEEXPORT_FILES=$(addprefix $(SSL_NODEEXPORT),.key .crt)
SSL_LOCALHOST=roles/ssl/files/localhost
SSL_LOCALHOST_FILES=$(addprefix $(SSL_LOCALHOST),.key .crt)
SSL_CDS=roles/ssl/files/cds
SSL_CDS_FILES=$(addprefix $(SSL_CDS),.key .crt)
SSL_GRAFANA=roles/grafana/files/ssl
SSL_GRAFANA_FILES=$(addprefix $(SSL_GRAFANA),.key .crt)

ifeq ($(wildcard $(VENDORTGZ)),)
VENDOR=
else
VENDOR=roles/domjudge_checkout/files/webapp/vendor
$(VENDOR): $(VENDORTGZ)
	-cd roles/domjudge_checkout/files/webapp && tar xzf ../$(notdir $<)
endif

ROLES=domserver judgehost admin grafana cds presclient presadmin scoreboard mgmt autoanalyst
$(ROLES): %: %.yml hosts group_vars/all/secret.yml $(VENDOR) $(SSHKEY) $(SSHKEY).pub
	ansible-playbook -i hosts $<

FAILED_ROLES=$(addprefix failed-,$(ROLES))
$(FAILED_ROLES): failed-%: %.yml %.retry
	ansible-playbook -i hosts --limit @$*.retry $<

CODEONLY_ROLES=$(addprefix codeonly-,domserver judgehost admin)
$(CODEONLY_ROLES): codeonly-%:
	ansible-playbook -i hosts --tags pretask,domjudge_build $*.yml

powerloss:
	ansible-playbook -i hosts emergency.yml --tags powerloss

lockdown:
	ansible-playbook -i hosts emergency.yml --tags full_lockdown

lockdown-force:
	ansible-playbook -i hosts emergency.yml --tags full_lockdown,force_lockdown

ansible-master:
	for book in $(ROLES) ; do \
		ansible-playbook -i hosts $$book.yml --tags install_master ; \
	done

admin: $(SSL_LOCALHOST_FILES)
grafana: $(SSL_GRAFANA_FILES) $(SSL_NODEEXPORT_FILES)
domserver: $(SSL_DOMSERVER_FILES) $(SSL_NODEEXPORT_FILES)
judgehost: $(SSL_NODEEXPORT_FILES)
cds: $(SSL_CDS_FILES) $(SSL_NODEEXPORT_FILES)
scoreboard: $(SSL_NODEEXPORT_FILES)
mgmt: $(SSL_NODEEXPORT_FILES)

$(SSHKEY) $(SSHKEY).pub:
	ssh-keygen -t ed25519 -f $(SSHKEY) -P ''

$(SSL_DOMSERVER_FILES):
	openssl req -x509 -nodes -newkey rsa:4096 -subj "/O=DOMjudge/CN=domjudge" \
        -addext "subjectAltName = DNS:wf46-domjudge,DNS:wf47-domjudge,DNS:analyst" \
		-sha256 -days 365 -keyout $(SSL_DOMSERVER).key -out $(SSL_DOMSERVER).crt
$(SSL_NODEEXPORT_FILES):
	openssl req -x509 -nodes -newkey rsa:4096 -subj "/O=DOMjudge/CN=metricexporter" \
		-sha256 -days 365 -keyout $(SSL_NODEEXPORT).key -out $(SSL_NODEEXPORT).crt
$(SSL_LOCALHOST_FILES):
	openssl req -x509 -nodes -newkey rsa:4096 -subj "/O=DOMjudge/CN=localhost" \
		-sha256 -days 365 -keyout $(SSL_LOCALHOST).key -out $(SSL_LOCALHOST).crt
$(SSL_CDS_FILES):
	openssl req -x509 -nodes -newkey rsa:4096 -subj "/O=DOMjudge/CN=cds" \
		-sha256 -days 365 -keyout $(SSL_CDS).key -out $(SSL_CDS).crt
$(SSL_GRAFANA_FILES):
	openssl req -x509 -nodes -newkey rsa:4096 -subj "/O=DOMjudge/CN=grafana" \
		-sha256 -days 365 -keyout $(SSL_GRAFANA).key -out $(SSL_GRAFANA).crt

clean:
	rm -rf $(VENDOR)

distclean: clean
	rm -f $(SSHKEY) $(SSHKEY).pub
	rm -f $(SSL_DOMSERVER_FILES)
	rm -f $(SSL_NODEEXPORT_FILES)
	rm -f $(SSL_LOCALHOST_FILES)
	rm -f $(SSL_CDS_FILES)
	rm -f $(SSL_GRAFANA_FILES)

.PHONY: default clean distclean $(ROLES) $(FAILED_ROLES) $(CODEONLY_ROLES) powerloss lockdown lockdown-force
