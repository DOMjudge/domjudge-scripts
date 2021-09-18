default:
	@echo "No default target available, run one of:"
	@echo
	@echo " - make domserver"
	@echo " - make domserver-only-code"
	@echo " - make judgehost"
	@echo " - make judgehost-only-code"
	@echo " - make admin"
	@echo " - make grafana"

LIBVENDORTGZ=files/lib-vendor.tgz

ifeq ($(wildcard $(LIBVENDORTGZ)),)
LIBVENDOR=
else
LIBVENDOR=files/lib/vendor
endif

domserver domserver-only-code judgehost judgehost-only-code admin grafana: %: %.yml hosts $(wildcard common_tasks*.yml) $(LIBVENDOR)
	ansible-playbook -i hosts $<

files/lib/vendor: $(LIBVENDORTGZ)
	-cd files && tar xzf $(notdir $<)

clean:
	rm -rf $(LIBVENDOR)

.PHONY: default clean domserver domserver-only-code judgehost judgehost-only-code admin grafana
