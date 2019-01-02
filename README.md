
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

 - `-s` - sets the one-time key size (in bits).  Default: 256

 - `-S` - sets the RSA key size (in bits).  Default: 4096


    hencrypt -v

Prints out version information.


# AIMS

This script aims to be useful for encrypting/decrypting large backup
files in an automated backup system for servers. Such a system
typically needs to encrypt large files, but any keys deployed to the
server for this are at risk of being captured.

## HYBRID ENCRYPTION

Public key (asymmetric) encryption would seem ideal for this, since
the encryption key on the server will be a different one to the
decryption key stored elsewhere. However it is slow and not really
suitable for encrypting large amounts of data. Whereas, symmetric
encryption is fast but uses the same key for encryption and
decryption.

"Hybrid encryption" is a combination of public key encryption and
symmetric encryption.  A public key is used to encrypt a one-time
key, which is then used to encrypt the payload. The encrypted
one-time key is stored with the encrypted payload.  Decryption
is done in reverse: the one-time key is decrypted first with the
private decryption key, and then used to decrypt the payload.

## OPENSSL OVER GNUPG

Ideally this encryption would be performed by an off-the-shelf tool
like GPG or openssl.  However, GPG tends not to be helpful for batch
encryption/decryption, and key management is complex. We want to avoid
needing to create a keyring (which is tied to a user directory) import
keys, mark them trusted etc.

OpenSSL is much simpler to use in this context, as it has no keyring
to manage. 

There does not currently seem to be a third option, except the NaCl
('salt') library (and forks thereof), which at the time of writing
does not seem to have a command-line interface.

## AVOIDANCE OF OPENSSL'S S/MIME IMPLEMENTATION

OpenSSL (again, at the time of writing) does not support anything
suitable for encrypting large files or streams. Although supports
S/MIME, which is a hybrid encryption scheme which would be suitable,
current versions of OpenSSL cannot decrypt S/MIME in stream mode. So
despite being able to encrypt files with openssl, you will not be able
to decrypt larger than about 2.5GB.

For some background about problems, see:

> "Attempting to decrypt/decode a large smime encoded file created with
> openssl fails regardless of the amount of OS memory available"

https://mta.openssl.org/pipermail/openssl-dev/2016-August/008237.html

Key points are:

- streaming smime *encryption* has been implemented, but
- smime *decryption* is done in memory, consequentially you can't decrypt
anything over 1.5G
- possibly this is related to the BUF_MEM structure's dependency on the size of
a C `int`

There's also a Github ticket here. Closed, apparently as "won't fix"
(yet?). This issue persists on (for example) the current Ubuntu LTS
release, Bionic Beaver (using OpenSSL 1.1.0g).

https://github.com/openssl/openssl/issues/2515

Note: One C implementation which claims to be able to decrypt large
S/MIME files is referenced in the comments.

## IMPLEMENTATION

Therefore this script was written to implement hybrid encryption of
large files using the basic scheme using the openssl CLI ourlined in
various places online, as simply as possible in Bash, whilst aiming to
be secure.

The `encrypt` function uses openssl to generate a cryptographically
secure random number as a one-time key (genonetime).

This is then encrypted with a public key (`rsaencrypt`), and sent
encoded in base64 as the second field of the encrypted stream to
stdout, followed by the encrypted payload read from stdin. The first
field is four characters encoding the number of characters of the
second in decimal.

The `decrypt` function first reads the 4-character decimal size field
`<N>` from stdin, then the `<encrypted key>` characters to get the
one-time key, decodes and decrypts it (`rsadecrypt`), then decrypts
the remainder of the openssl encrypted stream to stdout using it.

Stream format:

    <NN><versioninfo><NNNN><encrypted key><openssl encrypted stream>
	
 - `<NN>` - a 2 character decimal number indicating the characters in
   the following field.
 - `<versioninfo>` - contains information about the script and command
   versions, see below.
 - `<NNNN>` - a 4 character decimal number indicating the characters
   in the following field.
 - `<encrypted key>` - a base64-encoded RSA-encrypted one-time key.
 - `<openssl encrypted stream>` - the symmetric-encrypted payload.

The intention of the `<versioninfo>` field is to record the versions
of `hencrypt`, `openssl` and `base64` that were used to create an
encrypted file, for auditing purposes.  It is also to allow `hencrypt`
to identify broadly incompatible files which it cannot decrypt,
because of `hencrypt`'s own schematic differences. It has the form:

    hencrypt <X>.<Y>.<Z>\n<openssl>\n<base64>
	
Where:

   - The leading `hencrypt` keyword is required.
   - `<X>` is the major version number of hencrypt used.
   - `<Y>` is the minor version number of hencrypt used.
   - `<Z>` is the release version number of hencrypt used.
   - Only `<Z>` may differ between compatible versions.
   - `<openssl>` is line #1 of the version string output by `openssl version -a`.
   - `<base64>` is line #1 of the version string output by `base64 --version`.
   - The latter two are informational only.
   - `\n` is a line-feed character.
   

# CAVEATS / DISCLAIMER

This script works correctly to the best of my knowledge. However, as
ever with open source software: inspect the source code and use at
your own risk.

Although the choice of Bash for implementing this script may be
debatable considering the defensive programming required, by
piggy-backing on the openssl command-line programs this also avoids a
class of errors I gather is possible when using the OpenSSL API
directly. (Due to overflows and the potentially poor choices of
parameters allowed by the API.)  It is also more concise than an
equivalent would be if written in a language like C/Python/Perl/Ruby
and calling the `openssl` CLI. And it avoids requiring the non-core
libraries needed for direct OpenSSL API support.

Nevertheless, it is ultimately intended as a usable stop-gap until an
offically supported hybrid encryption tool becomes available.

Otherwise, I may yet add an implementation in an alternative language.


# REQUIREMENTS

 - bash
 - openssl
 - base64 (From the coreutils package on Debian/RedHat)

(Note: the base64 command is used in preference to openssl's base64
encoding as it can be coerced to write on a single line.)


The script aims to be self-contained so far as possible, and
deliberately does not use any other non built-in commands than these.


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
