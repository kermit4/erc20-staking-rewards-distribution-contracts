#!/bin/bash
unset tdir
[[ $1 ]] || tdir=test
set -e
find "$@" > /dev/null
! find $tdir "$@" -type f -name '*.js' \( -exec node -c {} \; -o \( -print -quit \)  \)  | 
    grep --quiet .
truffle test --runner-output-only "$@"
