#! /bin/bash

while true; do
    out=$(eval $@ 2>&1)
    if echo "$out" | grep -q kex_exchange_identification; then
        # sleep a little and retry
        echo after 100 | tclsh
    else
        echo Hello $@
        echo "$out"
        exit 0
    fi
done
