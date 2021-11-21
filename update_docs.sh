#!/bin/bash -ex

DOC_REPO=/home/domjudge/doc_update/doc_repo
WEBSERVER_PATH=/srv/http/domjudge/docs/manual
JSON="${WEBSERVER_PATH}/versions.json"

for version in `cat "${JSON}" | jq -r -c '.[]'`; do
	rm -rf "${WEBSERVER_PATH}/${version}"
	mkdir -p "${WEBSERVER_PATH}/${version}"
	(
	  cd "${DOC_REPO}"
	  git stash
	  git checkout "${version}"
	  git pull
	  rm -rf doc/manual/build/html/
	  if [ "$version" = "main" ]; then
		  sed -i -e "s/^version.*/version = 'main'/" doc/manual/version.py.in
	  fi
	  ./bootstrap
	  ./configure
	  make docs
	  cp -r doc/manual/build/html/* "${WEBSERVER_PATH}/${version}/"
	)
done
