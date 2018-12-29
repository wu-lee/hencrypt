

## GUIDELINES

In general we want our script to be super well behaved and fail early
and clearly if anything goes wrong. Therefore we use some defensive
programming tactics.

- Use local vars in functions
- Target Bash explicitly
- Signal errors with a `die` function
- Use pipefail, errexit options
- Check the return codes when shell expanding
- Preassign local when shell expanding
- Don't double shell-expand
- Don't use temp files
- Don't put sensitive data in parameters, pipe in via here-vars instead
- Don't put sensitive data in the environment
- Don't store binary data in vars, base64-encode it
- Always use full paths to external commands
- Quote variables by default, to avoid argument splitting
- Prefer printf over echo



## EXPLANATIONS


### Use local vars in functions

This is standard good programming practice, just perhaps a little
unusual in shell scripts because not all scripts support it. (Bash
does.)


### Target Bash explicitly.

We dispense with general ksh/sh shell script compatibility so we can
use bash features like `local`.  (Bash is chosen because it comes as
standard on most Linux distros.)


### Signal errors with a `die` function

We define a `die` function for convenience and consistency.

    false || die "some message"

This will print out the following on `stderr`:

    exiting: some message
	
And then call `exit 1`.

(For convenience we also define a `warn` function which simply prints
on `stderr` but doesn't exit.)


### Use pipefail, errexit options

By default, failure return codes in piped commands are ignored:

    false | cat > /dev/null # error is ignored
	
To prevent silent failure, set the pipefail option:

    set -o pipefail

By default, failures in general don't halt the script.

    false # will not halt the script
	
To halt with a failure if any command fails, set the errexit option:

	set -o errexit
	
Note that this will not make errors in subshells exit the script, but
see below.


### Check the return codes when shell expanding

Errors in backticks/shell-expansions do not get caught, even with she:

    foo=$(false) # does not fail

So check for errors explicitly:

    foo=$(false) || die "something failed"


### Preassign local when shell expanding

The above trick will not work with `local`:

    local foo=$(false) || die "something failed" # will never die
	
This is because local suppresses the return code of the shell
expansion.

However, you can pre-declare the variable instead:

    local foo
	foo=$(false) || die "something failed" # this works as above
	

### Don't double shell-expand

If you combine more than one shell-expansion, any errors in the
earlier shell expansions are lost:

    foo=xx$(false)$(false)$(true)xx || die "something failed"

So best not to do that. Do this instead:

    a=$(false) || die "a failed"
    b=$(false) || die "b failed"
	c=$(true) || die "c failed" 
    foo=$a$b$c


### Don't use temp files

Temporary files are a well known security risk. This not only writes
secret data where it can be read:

    echo secret1 >/tmp/foo
    echo secret2 >>/tmp/foo
	something </tmp/foo

But also it can be hijacked by placing a symlink in /tmp/foo pointing
elsewhere, and that can be used to destructively overwrite data.

Generally if you have to use a temp file, use `mktemp` to create it.
But if you can avoid that too, all the better (and often simpler).

Here we try and use pipes instead of temp files. For example:

    ( echo secret1 && echo secret2 ) | something

However, beware of errors in the subshell. Check for them explicitly
as described above.


### Don't put sensitive data in parameters

The process table includes command parameters (after shell expansion),
and is public, so don't let sensitive data appear there like this:

    dosomething -with $secret

Use pipes instead whenever possible.

    dosomething -withstdin <<<$secret


### Don't put sensitive data in the environment

Likewise environment variables are generally public:

    export SECRET=secret!
    dosomething -withenv SECRET

Again, use pipes instead.

Unexported shell variables are ok however:

    SECRET=secret!
	dosomething -withstdin <<<$SECRET


### Don't store binary data in vars, base64-encode it

Don't do this with binary data:

    data=$(printbinarydata) || die "something failed"
	
Shell variables cannot sanely include null characters. Base64 encode
the data if it might contain nulls:

    data=$(printbinarydata | /usr/bin/base64 -w0) ||
		die "something failed"


### Always use full paths to external commands

Don't do things like this:

    data=$(printbinarydata | base64 -w0) ||
		die "something failed"

    cat /dev/urandom | somwhere

In this example, `die`, `somewhere` and `printbinarydata` are shell
functions or built-ins, and so are safe, but `base64` and `cat` are
external programs which are found via the PATH environment variable,
which can be redefined to inject malicious versions of these
commands. Use the full path:

    CAT=/bin/cat
	BASE64=/usr/bin/base64
	
    data=$(printbinarydata | $BASE64 -w0) ||
		die "something failed"

    $CAT /dev/urandom | somwhere


### Quote variables by default, to avoid argument splitting

In general, always quote variable expansions to avoid surprises like
this:

    msg="-e e-"
    echo $msg # prints "e-"

    msg="foo      bar"
    echo $msg # prints "foo bar"
	
	path="/something with spaces"
	rm $path # removes "/something", "with" and "spaces"

However there may be times when you actually want this:

    options="-a -b -c"
	dosomething $options # like: dosomething -a -b -c
	dosomething "$options" # like: dosomething "-a -b -c"


### Prefer printf over echo

It's generally a bit more predictable, and doesn't try to interpret
options (as above).


