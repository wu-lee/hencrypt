#!/usr/bin/env bats # -*- shell-script -*-

# test normal usage
function standard_usage {
    ../hencrypt -g tmp/key &&
    ../hencrypt -e tmp/key.pub <data/lorem >tmp/enc &&
    ../hencrypt -d tmp/key <tmp/enc >tmp/lorem
}

function setup {
    # Recreate the tmp directory
    rm -rf tmp
    mkdir -p tmp
}

@test "standard usage case: create, encode, restore" {
    run standard_usage
    [ "$status" -eq 0 ]
    diff -q data/lorem tmp/lorem
}
