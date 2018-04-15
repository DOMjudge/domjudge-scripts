default:
	@echo "No default target available, run one of:"
	@echo
	@echo " - make domserver"
	@echo " - make judgehost"

domserver judgehost: %: %.yml hosts $(wildcard common_tasks*.yml) files/lib/vendor
	ansible-playbook -i hosts $<

files/lib/vendor: files/lib-vendor.tgz
	cd files && tar xzf lib-vendor.tgz

clean:
	rm -rf files/lib/vendor

.PHONY: default clean domserver judgehost
