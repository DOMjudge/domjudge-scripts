SHELL = /bin/bash

WWWDIR = /srv/http/domjudge

install:
	cp *.shtml *.css *.ico *.png *.pdf $(WWWDIR)/

# This takes the docs from the latest (by string sorting) release and copies
# these to the directory serving files under www.domjudge.org/docs/.
install-docs:
	-rm -f $(WWWDIR)/docs/team-manual.pdf
	-rm -f $(WWWDIR)/docs/manual
	-mkdir $(WWWDIR)/docs/manual
	LATEST=`ls /srv/http/domjudge/releases/domjudge-*.tar.gz | sort | tail -1` ; \
	TEMP=`mktemp -d` ; cd $$TEMP ; tar xzf $$LATEST ; \
	cp domjudge-*/doc/team/team-manual*.pdf $(WWWDIR)/docs/ ; \
	cp -r domjudge-*/doc/manual/build/html/* $(WWWDIR)/docs/manual/ ; \
	rm -rf $$TEMP
