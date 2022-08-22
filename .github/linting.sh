#!/usr/bin/bash

set -euxo pipefail

# shellcheck disable=SC2044
for book in $(find ./ -maxdepth 1 -name "*.yml"); do
    if [ "$book" != "./handlers.yml" ]; then
        ansible-lint "$book" -x 'braces,yaml[line-length]'
    fi
done
# shellcheck disable=SC2044
for dir in $(find ./roles -maxdepth 1 -type d); do
    ansible-lint "$dir" -x 'braces,yaml[line-length]'
done
