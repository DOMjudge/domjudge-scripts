default:
	@echo "No default target available, run one of:"
	@echo
	@echo " - make domserver"
	@echo " - make judgehost"
	@echo " - make admin"
	@echo " - make grafana"
	@echo " - make cds"
	@echo " - make scoreboard"
	@echo " - make autoanalyst"

LIBVENDORTGZ=roles/domjudge_checkout/files/lib-vendor.tgz
SSHKEY=roles/ssh/files/id_ed25519
SSL_DOMSERVER=roles/ssl/files/domserver
SSL_DOMSERVER_FILES=$(addprefix $(SSL_DOMSERVER),.key .crt)
SSL_LOCALHOST=roles/ssl/files/localhost
SSL_LOCALHOST_FILES=$(addprefix $(SSL_LOCALHOST),.key .crt)
SSL_CDS=roles/ssl/files/cds
SSL_CDS_FILES=$(addprefix $(SSL_CDS),.key .crt)
SSL_GRAFANA=roles/grafana/files/ssl
SSL_GRAFANA_FILES=$(addprefix $(SSL_GRAFANA),.key .crt)

ifeq ($(wildcard $(LIBVENDORTGZ)),)
LIBVENDOR=
else
LIBVENDOR=roles/domjudge_checkout/files/lib/vendor
$(LIBVENDOR): $(LIBVENDORTGZ)
	-cd roles/domjudge_checkout/files && tar xzf $(notdir $<)
endif

ROLES=domserver judgehost admin grafana cds scoreboard mgmt autoanalyst
$(ROLES): %: %.yml hosts group_vars/all/secret.yml $(LIBVENDOR) $(SSHKEY) $(SSHKEY).pub
	ansible-playbook -i hosts $<

CODEONLY_ROLES=$(addprefix codeonly-,domserver judgehost admin)
$(CODEONLY_ROLES): codeonly-%:
	ansible-playbook -i hosts --tags pretask,domjudge_build $*.yml

powerloss:
	ansible-playbook -i hosts emergency.yml --tags powerloss

lockdown:
	ansible-playbook -i hosts emergency.yml --tags full_lockdown

lockdown-force:
	ansible-playbook -i hosts emergency.yml --tags full_lockdown,force_lockdown

admin: $(SSL_LOCALHOST_FILES)
grafana: $(SSL_GRAFANA_FILES)
domserver: $(SSL_DOMSERVER_FILES)
cds: $(SSL_CDS_FILES)

$(SSHKEY) $(SSHKEY).pub:
	ssh-keygen -t ed25519 -f $(SSHKEY) -P ''

$(SSL_DOMSERVER_FILES):
	openssl req -x509 -nodes -newkey rsa:4096 -subj "/O=DOMjudge/CN=domjudge" \
		-sha256 -days 365 -keyout $(SSL_DOMSERVER).key -out $(SSL_DOMSERVER).crt
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
	rm -rf $(LIBVENDOR)

distclean: clean
	rm -f $(SSHKEY) $(SSHKEY).pub
	rm -f $(SSL_DOMSERVER_FILES)
	rm -f $(SSL_LOCALHOST_FILES)
	rm -f $(SSL_CDS_FILES)
	rm -f $(SSL_GRAFANA_FILES)

.PHONY: default clean distclean $(ROLES) $(CODEONLY_ROLES) powerloss lockdown lockdown-force
