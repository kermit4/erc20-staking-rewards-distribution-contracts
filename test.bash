#!/bin/bash
tdir=""
set -e
[[ $1 ]] || tdir=test
find $tdir "$@" > /dev/null
find $tdir "$@" -type f -name '*.js' -print0 | xargs -0 -n 1 node -c
find $tdir "$@" -type f -name '*.js' -print0 | xargs -0 -n 1 truffle test --runner-output-only 
