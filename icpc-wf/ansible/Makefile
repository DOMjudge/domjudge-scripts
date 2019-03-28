default:
	@echo "No default target available, run one of:"
	@echo
	@echo " - make domserver"
	@echo " - make judgehost"
	@echo " - make admin"

LIBVENDORTGZ=files/lib-vendor.tgz

ifeq ($(wildcard $(LIBVENDORTGZ)),)
LIBVENDOR=
else
LIBVENDOR=files/lib/vendor
endif

domserver judgehost admin: %: %.yml hosts $(wildcard common_tasks*.yml) $(LIBVENDOR)
	ansible-playbook -i hosts $<

files/lib/vendor: $(LIBVENDORTGZ)
	-cd files && tar xzf $(notdir $<)

clean:
	rm -rf $(LIBVENDOR)

.PHONY: default clean domserver judgehost admin
