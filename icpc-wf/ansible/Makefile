default:
	@echo "No default target available, run one of:"
	@echo
	@echo " - make domserver"
	@echo " - make domserver-only-code"
	@echo " - make judgehost"
	@echo " - make judgehost-only-code"
	@echo " - make admin"
	@echo " - make grafana"

LIBVENDORTGZ=roles/domjudge_checkout/files/lib-vendor.tgz
SSHKEY=roles/ssh/files/id_rsa

ifeq ($(wildcard $(LIBVENDORTGZ)),)
LIBVENDOR=
else
LIBVENDOR=roles/domjudge_checkout/files/lib/vendor
$(LIBVENDOR): $(LIBVENDORTGZ)
	-cd roles/domjudge_checkout/files && tar xzf $(notdir $<)
endif

domserver domserver-only-code judgehost judgehost-only-code admin grafana: %: %.yml hosts $(wildcard common_tasks*.yml) $(LIBVENDOR) $(SSHKEY) $(SSHKEY).pub
	ansible-playbook -i hosts $<

$(SSHKEY) $(SSHKEY).pub:
	ssh-keygen -t rsa -f $(SSHKEY) -P ''

clean:
	rm -rf $(LIBVENDOR)

distclean: clean
	rm -rf $(SSHKEY) $(SSHKEY).pub

.PHONY: default clean distclean domserver domserver-only-code judgehost judgehost-only-code admin grafana
