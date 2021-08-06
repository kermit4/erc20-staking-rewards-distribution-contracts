#!/bin/bash
tdir=""
set -e
export TMPDIR=`mktemp --tmpdir --directory  yarntestXXXXXXXXXXX`
trap "fuser -swk $TMPDIR/*;rm -rf $TMPDIR" EXIT
[[ $1 ]] || tdir=test
ganache-cli  -i 1000 > $TMPDIR/ganache 2> $TMPDIR/ganache.2 &
find $tdir "$@" > /dev/null
find $tdir "$@" -type f -name '*.js' -print0 | xargs -0 -n 1 node -c 
find $tdir "$@" -type f -name '*.js' -print0 | xargs -0 -n 1 truffle test --stacktrace-extra --runner-output-only >(tee test.out) 2>(tee test.err)
echo -e \\a
