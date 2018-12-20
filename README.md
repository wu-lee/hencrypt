
Hybrid encryption of large files using openssl.

The script aims to be self-contained, so see inline documentation
within the `hencrypt` script itself.

## TESTS

There are some test cases in the `test/` directory.

These use the [bats](https://github.com/bats-core/bats-core) testing
framework. This can be installed a number of ways, and a package.json
file is included to support installation with `npm` (although this is
not mandatory). A bonus of adding a package.json is that it provides
licence and version management.

    npm install --save-dev bats
	
If you use npm, then you can run the tests like this:

    npm test
	
Or directly like this:

    (cd tests; bats .)
	

