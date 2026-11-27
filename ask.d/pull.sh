#!/bin/sh
# id: 12
# group: MAINTENANCE
# desc: Pull - git pull the repo
. "$(dirname "$0")/lib.sh"

set -e
enter

git pull
printf "ok    pulled\n"