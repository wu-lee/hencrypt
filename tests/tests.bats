#!/usr/bin/env bats # -*- shell-script -*-


# This wrapper exists to avoid using IO redirection params in tests
# (because bats uses the 'run' wrapper command).  It calls hencrypt
# with the last two params defining the file redirection for stdin and
# stdout, respectively.
#
# i.e. This:
#
#   HENCRYPT_IO a b c d
#
# becomes:
#
#   ../hencrypt a b <c >d
#
# Obviously, it is only needed when redirection is performed.
function HENCRYPT_IO {
    local out=${@: -1:1}
    local in=${@: -2:1}
#    echo "hencrypt ${@:1:$#-2} <$in >$out" >&3
    ../hencrypt "${@:1:$#-2}" <"$in" >"$out"
}


# test normal usage
function standard_usage {
    ../hencrypt -g tmp/key &&
    ../hencrypt -e tmp/key.pub <data/lorem >tmp/enc &&
    ../hencrypt -d tmp/key <tmp/enc >tmp/lorem
}

function loop_over_options {
    # Valid options, just incompatible
    for opts in -{h,e,d,g,v}{h,e,d,g,v}; do
        run ../hencrypt $opts data/key1
	#printf "debug: %s %s\n" $opts "$output" >&3
        [ "$status" -ne 0 ] || return 1
        grep 'exiting: can only use one of -h -e -d -g or -v' <<<$output || return 1
    done
    return 0
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

@test "resist PATH hijacking" {
    # the dummy dir contains fake commands like cat, base64, openssl
    PATH=dummy:$PATH run standard_usage
    [ "$status" -eq 0 ] || echo rc $status $output
    diff -q data/lorem tmp/lorem
}

@test "decrypt pre-encrypted data 1" {
    run HENCRYPT_IO -d data/key1 data/enc1 tmp/dec
    [ "$status" -eq 0 ]
    diff -q data/lorem tmp/dec
}

@test "decrypt pre-encrypted data 2" {
    run HENCRYPT_IO -d data/key2 data/enc2 tmp/dec
    [ "$status" -eq 0 ]
    diff -q data/lorem tmp/dec
}

@test "bad key encrypt failure" {
    # key1 is a bad encrypt key
    run HENCRYPT_IO -e data/key1 data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'unable to load Public Key' <<<$output
    grep 'exiting: rsaencrypt failed' <<<$output
}

@test "bad key decrypt failure" {
    # key1.pub is a bad decrypt key
    run HENCRYPT_IO -d data/key1.pub data/enc1 tmp/lorem
    [ "$status" -ne 0 ]
    # Don't check for this message in case openssl change their output.
    #grep 'unable to load Private Key' <<<$output
    grep 'exiting: rsadecrypt failed' <<<$output
}

@test "wrong key decrypt failure" {
    # key2 is wrong decrypt key for key1.pub
    run HENCRYPT_IO -d data/key2 data/enc1 tmp/lorem
    [ "$status" -ne 0 ]
    # openssl error resulting from using the wrong key seems to be,
    # ahem, cryptic.  Thus we don't attempt to check for it, in case
    # it changes.
    #grep 'RSA_EAY_PRIVATE_DECRYPT:padding check failed' <<<$output
    grep 'exiting: rsadecrypt failed' <<<$output
}

@test "payload/one-time key mismatch decrypt failure" {
    # key1 is right decrypt key for key1.pub, but enc.stitched has
    # another payload stitched on to a valid encrypted one-time key
    run HENCRYPT_IO -d data/key1 data/enc.stitched tmp/lorem
    [ "$status" -ne 0 ]
    grep 'exiting: failed to decrypt' <<<$output
}

@test "truncated payload decrypt failure" {
    # key1 is right decrypt key for key1.pub, but enc.stitched has
    # another payload stitched on to a valid encrypted one-time key
    run HENCRYPT_IO -d data/key1 data/enc.truncated tmp/lorem
    [ "$status" -ne 0 ]
    grep 'exiting: failed to decrypt' <<<$output
}

@test "no options or parameters" {
    run ../hencrypt
    [ "$status" -ne 0 ]
    grep 'USAGE:' <<<$output
    grep 'exiting: you must supply a key file as the only argument' <<<$output
}

@test "too many parameters" {
    # Valid options, just too many.
    run ../hencrypt -d data/key1 data/key2
    [ "$status" -ne 0 ]
    grep 'exiting: you must supply a key file as the only argument' <<<$output
}

@test "incompatible options" {
    # bats uses preprocessing magic, so doesn't support looping tests,
    # and we need to loop in a helper function
    run loop_over_options
    [ "$status" -eq 0 ]
}

@test "help" {
    run ../hencrypt -h
    [ "$status" -eq 0 ]
    grep 'USAGE:' <<<$output
}

@test "bad options: nonnumeric -s" {
    run HENCRYPT_IO -s 25g -e data/key1.pub data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: one-time key size must be numeric and positive' <<<$output
}

@test "bad options: nonnumeric -S" {
    run HENCRYPT_IO -S 4o96 -e data/key1.pub data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: RSA key size must be numeric and positive' <<<$output
}

@test "bad options: zero -s" {
    run HENCRYPT_IO -s 0 -e data/key1.pub data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: one-time key size must be numeric and positive' <<<$output
}

@test "bad options: zero -S" {
    run HENCRYPT_IO -S 0 -e data/key1.pub data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: RSA key size must be numeric and positive' <<<$output
}

@test "bad options: negative -s" {
    run HENCRYPT_IO -s -256 -e data/key1.pub data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: one-time key size must be numeric and positive' <<<$output
}

@test "bad options: negative -S" {
    run HENCRYPT_IO -S -4096 -e data/key1.pub data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: RSA key size must be numeric and positive' <<<$output
}

@test "missing encryption key" {
    run HENCRYPT_IO -e tmp/missing data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: no such file: tmp/missing' <<<$output
}

@test "missing decryption key" {
    run HENCRYPT_IO -d tmp/missing data/lorem tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: no such file: tmp/missing' <<<$output
}

@test "empty encryption key" {
    printf "" >tmp/empty
    run HENCRYPT_IO -e tmp/empty data/lorem tmp/enc
    [ "$status" -ne 0 ]
    grep 'exiting: rsaencrypt failed' <<<$output
}

@test "empty file encrypting" {
    printf "" >tmp/empty
    run HENCRYPT_IO -e data/key1.pub tmp/empty tmp/enc
    [ "$status" -eq 0 ]
    [ -s tmp/enc ]
}

@test "bad versioninfo length in file decrypting" {
    printf "0." >tmp/bad
    run HENCRYPT_IO -d data/key1 tmp/bad tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: invalid versioninfo length field encountered whilst decrypting' <<<$output
}

@test "short versioninfo length field in file decrypting" {
    printf "1" >tmp/bad
    run HENCRYPT_IO -d data/key1 tmp/bad tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: EOF reading versioninfo length field' <<<$output
}

@test "overlong versioninfo length in file decrypting" {
    printf "10a" >tmp/bad
    run HENCRYPT_IO -d data/key1 tmp/bad tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: EOF reading versioninfo field' <<<$output
}

# This should  be a valid and acceptable versioninfo field
versioninfo=$'22hencrypt 0.1.0\nxxx\nxxx'

@test "bad one-time key length in file decrypting" {
    printf "${versioninfo}000." >tmp/bad
    run HENCRYPT_IO -d data/key1 tmp/bad tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: invalid one-time key length field encountered whilst decrypting' <<<$output
}

@test "short one-time key length field in file decrypting" {
    printf "${versioninfo}001" >tmp/bad
    run HENCRYPT_IO -d data/key1 tmp/bad tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: EOF reading one-time key length field' <<<$output
}

@test "overlong length in file decrypting" {
    printf "${versioninfo}0010x" >tmp/bad
    run HENCRYPT_IO -d data/key1 tmp/bad tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: EOF reading one-time key field' <<<$output
}

@test "will not decrypt files without 'hencrypt' keyword" {
    printf "22hencript 0.1.0\nxxx\nyyy" >tmp/bad
    run HENCRYPT_IO -d data/key2 tmp/bad tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: not a hencrypt file' <<<$output
}

@test "will decrypt files with compatible version difference" {
    run HENCRYPT_IO -d data/key2 data/enc.goodversion tmp/dec
    [ "$status" -eq 0 ]
    diff -q data/lorem tmp/dec
}

@test "will not decrypt files with incompatible version difference" {
    run HENCRYPT_IO -d data/key2 data/enc.badversion tmp/dec
    [ "$status" -ne 0 ]
    grep 'exiting: hencrypt version mismatch' <<<$output
}
