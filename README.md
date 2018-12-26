
# TITLE

hencrypt - Hybrid encryption of potentially large datastreams.


# SYNOPSYS

    # Generate a new RSA keypair in files key and key.pub
    hencrypt -g key
	
	# Encrypt a file using the public key in key.pub
    hencrypt -e key.pub <data >encoded
	
	# Decrypt the encoded data using the private key
    hencrypt -d key <encoded >decoded


# USAGE

    hencrypt -h 

Prints this usage.


    hencrypt [-S] -g <keyfile>

Generates a new RSA keypair in <keyfile> and copies the public portion
to <keyfile>.pub. Use the former for decryption, and the latter for
encryption.


    hencrypt [-s] -e <keyfile.pub>

Encrypts stdin to stdout using the supplied public key file


    hencrypt -d <keyfile>

Decrypts stdin to stdout, using the supplied private key file (may
also be a keypair file).


The following options can be supplied in some cases (as indicated),
and are ignored otherwise:

 - `-s` - sets the one-time password size (in bits).  Default: 256

 - `-S` - sets the RSA key size (in bits).  Default: 4096


# AIMS

This script aims to be useful for encrypting/decrypting large backup
files in an automated backup system for servers. Such a system
typically needs to encrypt large files, but any keys deployed to the
server for this are at risk of being captured.

Public key (asymmetric) encryption would seem ideal for this, since
the encryption key on the server will be a different one to the
decryption key stored elsewhere. However it is slow and not really
suitable for encrypting large amounts of data. Whereas, symmetric
encryption is fast but uses the same key for encryption and
decryption.

"Hybrid encryption" is a combination of public key encryption and
symmetric encryption.  A public key is used to encrypt a one-time
password, which is then used to encrypt the payload. The encrypted
one-time password is stored with the encrypted payload.  Decryption
is done in reverse: the one-time key is decrypted first with the
private decryption key, and then used to decrypt the payload.

Ideally this would be performed by an off-the-shelf tool like GPG or
openssl.  However, GPG tends not to be helpful for batch
encryption/decryption, and key management is complex. We want to
avoid needing to create a keyring (which is tied to a user
directory) import keys, mark them trusted etc.

OpenSSL is much simpler to use in this context, as it has no keyring
to manage. But at the time of writing, it does not support anything
suitable for encrypting large files or streams. It supports SMIME,
which nominally would achieve this, but current versions cannot
decrypt in stream mode, and so despite being able to encrupt a file
larger than about 2.5GB, you will not be able to decrypt it with
openssl.

Therefore this script was written to implement hybrid encryption of
large files using openssl.

Below, the encrypt function uses openssl to generate a
cryptographically secure random number as a one-time password
(genonetime).

This is then encrypted with a public key (rsaencrypt), and sent
encoded in base64 as the first line of the encrypted stream to
stdout, followed by the encrypted payload read from stdin.

The decrypt function first reads a line from stdin to get the
one-time password, decodes and decrypts it (rsadecrypt), then
decrypts the remainder of the input stream to stdout using it.


# REQUIREMENTS

 - bash
 - openssl
 - base64 (From the coreutils package on Debian/RedHat)

(Note: the base64 command is used in preference to openssl's base64
encoding as it can be coerced to write on a single line.)


The script aims to be self-contained, so see inline documentation
within the `hencrypt` script itself.


# TESTS

There are some test cases in the `test/` directory.

These use the [bats][3] testing framework. This can be installed a
number of ways, and a `package.json` file is included to support
installation with `npm` (although this is not mandatory). A bonus of
adding a `package.json` is that it provides licence and version
management.

    npm install --save-dev bats
	
If you use npm, then you can run the tests like this:

    npm test
	
Or directly like this:

    (cd tests; bats .)
	

# BUGS / CONTRIBUTIONS

See the project page at https://github.com/wu-lee/hencrypt


# AUTHOR / CREDITS

Original author: [Nick Stokoe][1], November 2018

Inspired by a [blog entry][2] by Dmitry Bikulov.

[1]: https://github.com/wu-lee
[2]: http://bikulov.org/blog/2013/10/12/hybrid-symmetric-asymmetric-encryption-for-large-files/
[3]: https://github.com/bats-core/bats-core
