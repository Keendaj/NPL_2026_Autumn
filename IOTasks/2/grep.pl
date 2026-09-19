#!/usr/bin/perl
use strict;
use warnings;
use open qw(:std :encoding(UTF-8));
use Getopt::Long qw(:config bundling no_ignore_case no_auto_abbrev);
use File::Find ();

my %opt;
GetOptions(
    \%opt,
    'ignore-case|i',
    'invert-match|v',
    'line-number|n',
    'count|c',
    'files-with-matches|l',
    'recursive|r',
    'word-regexp|w',
    'fixed-strings|F',
    'no-filename|h',
    'max-count|m=i',
    'help',
) or usage(2);

usage(0) if $opt{help};
usage(2) unless @ARGV;

my $pattern = shift @ARGV;
my @targets = @ARGV;    

my $body = $opt{'fixed-strings'} ? quotemeta($pattern) : $pattern;
$body = '\b(?:' . $body . ')\b' if $opt{'word-regexp'};

my $re = eval { $opt{'ignore-case'} ? qr/$body/i : qr/$body/ };
if (!$re) {
    my $err = $@ || 'incorrect pattern';
    $err =~ s/\s+at\s+\S+\s+line\s+\d+\.?\s*$//;
    print STDERR "grep.pl: error in regexp: $err\n";
    exit 2;
}

exit 1 if defined $opt{'max-count'} && $opt{'max-count'} == 0;

my @files = expand(@targets);
my $show_name = !$opt{'no-filename'} && @files > 1;
my $total = 0;

for my $file (@files) {
    my $fh;
    if ($file eq '-') {
        $fh = \*STDIN;
    }
    elsif (!open $fh, '<', $file) {
        warn "grep.pl: $file: $!\n";
        next;
    }

    my $label  = $file eq '-' ? '(stdin)' : $file;
    my $count  = 0;
    my $lineno = 0;

    while (my $line = <$fh>) {
        $lineno++;
        chomp $line;

        my $hit = $line =~ $re ? 1 : 0;
        $hit = $hit ? 0 : 1 if $opt{'invert-match'};
        next unless $hit;

        $count++;
        $total++;

        if ($opt{'files-with-matches'}) {
            print "$label\n";
            last;
        }

        unless ($opt{count}) {
            my @parts;
            push @parts, $label  if $show_name;
            push @parts, $lineno if $opt{'line-number'};
            push @parts, $line;
            print join(':', @parts), "\n";
        }

        last if defined $opt{'max-count'} && $count >= $opt{'max-count'};
    }

    if ($opt{count}) {
        print $show_name ? "$label:$count\n" : "$count\n";
    }

    close $fh unless $file eq '-';
}

exit($total ? 0 : 1);

sub expand {
    my @in = @_;
    return ('-') unless @in;
    return @in unless $opt{recursive};

    my @out;
    for my $target (@in) {
        if (-d $target) {
            File::Find::find(
                {
                    no_chdir => 1,
                    wanted   => sub { push @out, $File::Find::name if -f $File::Find::name },
                },
                $target
            );
        }
        else {
            push @out, $target;
        }
    }
    return @out;
}

sub usage {
    my ($code) = @_;
    my $text = <<'USAGE';
    Usage: grep [OPTION]... PATTERNS [FILE]...
    Search for PATTERNS in each FILE.
    Example: grep -i 'hello world' menu.h main.c
    PATTERNS can contain multiple patterns separated by newlines.

    -i                ignore case distinctions in patterns and data
    --help            display this help text and exit
    -m NUM            stop after NUM selected lines
    -n                print line number with output lines
    -h                suppress the file name prefix on output
    -r                like --directories=recurse
    -l                print only names of FILEs with selected lines
    -c                print only a count of selected lines per FILE

    Exit status is 0 if any line is selected,
    1 otherwise; if any error occurs the exit status is 2.
USAGE
    print {$code ? \*STDERR : \*STDOUT} $text;
    exit $code;
}
