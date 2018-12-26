#!/usr/bin/perl
use strict;
use warnings;

my $README = 'README.md';
my $HENCRYPT = 'hencrypt';


# Accepts a code block and a filename.
# Applies the code block to each line of the file
# (with $_ locally defined to the line).
sub with_lines(&$) {
    my $sub = shift;
    my $file = shift;
    open my $fh, $file
        or die "Failed to open file $file: $!";
    local ($_, $.);
    while(<$fh>) {
        $sub->();
    }
    close $fh
        or die "Failed to close file $file: $!";
}



sub in_section {
    my $section = shift;
    # Exclusive range match. Excludes first (1) and
    # last (ends with 'E0') truthy result.
    my ($ix) = (/^# $section/.../^# .+/) =~ /(\d+)\z/;
    return $ix && $ix > 1;
}

sub in_heredoc {
    my $delim = shift;
    # Exclusive range match. Excludes first (1) and
    # last (ends with 'E0') truthy result.
    my ($ix) = (/<<\s*["']?$delim["']?/.../^$delim$/) =~ /(\d+)\z/;
    return $ix && $ix > 1;
}

my @usage;

# Slurp the sections we want into @usage
with_lines {
    push @usage, $_
        if in_section 'TITLE';
} $README;

push @usage, "USAGE:\n";

with_lines {
    push @usage, $_
        if in_section 'USAGE';
} $README;

open my $fh, '>', "$HENCRYPT.new"
    or die "Failed top open $HENCRYPT.new for writing: $!";

# Insert them into a new copy of the script
with_lines {
    # Print non-usage lines of script
    print $fh $_ and return
        if !in_heredoc 'USAGE';

    # Otherwise print the usage - but just once.
    print $fh @usage
        if @usage;

    @usage = ();
} $HENCRYPT;

close $fh
    or die "Failed top close $HENCRYPT.new for writing: $!";

rename "$HENCRYPT.new", $HENCRYPT
    or die "Failed to rename $HENCRYPT.new as $HENCRYPT: $!";
chmod 0755, $HENCRYPT;
