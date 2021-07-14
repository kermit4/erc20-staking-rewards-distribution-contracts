#!/bin/bash
unset tdir
[[ $1 ]] || tdir=test
set -e
find "$@" > /dev/null
! find $tdir "$@" -type f -name '*.js' \( -exec node -c {} \; -o \( -print -quit \)  \)  | 
    grep --quiet .
! find $tdir "$@" -type f -name '*.js' \( -exec truffle test --runner-output-only {} \; -o \( -print -quit \)  \)  | 
    grep --quiet .
