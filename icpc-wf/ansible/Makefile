default:
	@echo "No default target available, run one of:"
	@echo
	@echo " - make domserver"
	@echo " - make judgehost"
	@echo " - make admin"
	@echo " - make grafana"

LIBVENDORTGZ=roles/domjudge_checkout/files/lib-vendor.tgz
SSHKEY=roles/ssh/files/id_rsa
SSL_LOCALHOST=roles/ssl/files/localhost
SSL_LOCALHOST_FILES=$(addprefix $(SSL_LOCALHOST),.key .crt)

ifeq ($(wildcard $(LIBVENDORTGZ)),)
LIBVENDOR=
else
LIBVENDOR=roles/domjudge_checkout/files/lib/vendor
$(LIBVENDOR): $(LIBVENDORTGZ)
	-cd roles/domjudge_checkout/files && tar xzf $(notdir $<)
endif

domserver judgehost admin grafana: %: %.yml hosts $(wildcard common_tasks*.yml) $(LIBVENDOR) $(SSHKEY) $(SSHKEY).pub
	ansible-playbook -i hosts $<

admin: $(SSL_LOCALHOST_FILES)

$(SSHKEY) $(SSHKEY).pub:
	ssh-keygen -t rsa -f $(SSHKEY) -P ''

$(SSL_LOCALHOST_FILES):
	openssl req -x509 -nodes -newkey rsa:4096 -subj "/O=DOMjudge/CN=localhost" \
		-sha256 -days 365 -keyout $(SSL_LOCALHOST).key -out $(SSL_LOCALHOST).crt

clean:
	rm -rf $(LIBVENDOR)

distclean: clean
	rm -f $(SSHKEY) $(SSHKEY).pub
	rm -f $(SSL_LOCALHOST_FILES)

.PHONY: default clean distclean domserver judgehost admin grafana
