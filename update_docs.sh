#!/bin/sh -e

WEBSERVER_PATH=/srv/http/domjudge/docs/manual
JSON="${WEBSERVER_PATH}/versions.json"

TMPDIR=$(mktemp -d -t 'update_docs-XXXXXX')
DOC_REPO="$TMPDIR/domjudge"

cleanup()
{
    rm -rf "$TMPDIR"
}

trap cleanup EXIT

git clone https://github.com/DOMjudge/domjudge.git "$DOC_REPO"

for version in $(jq -r -c '.[]' < "${JSON}") ; do
	rm -rf "${WEBSERVER_PATH:?}/${version}"
	mkdir -p "${WEBSERVER_PATH}/${version}"
	(
		cd "$DOC_REPO"
		git reset --hard HEAD
		git clean -df
		git checkout "$version"
		rm -rf doc/manual/build/html/
		rm -rf lib/vendor/
		if [ "$version" = "main" ]; then
			sed -i -e "s/^version.*/version = 'main'/" doc/manual/version.py.in
		fi
		./bootstrap
		./configure
		make docs
		cp -r doc/manual/build/html/* "${WEBSERVER_PATH}/${version}/"
	)
done

# Use versionswitcher from main branch which has several fixes
for version in $(jq -r -c '.[]' < "${JSON}") ; do
	if [ "$version" != "main" ]; then
		cp "${WEBSERVER_PATH}/main/_static/js/versionswitcher.js" "${WEBSERVER_PATH}/${version}/_static/js/versionswitcher.js"
	fi
done
