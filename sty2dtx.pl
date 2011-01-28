#!/usr/bin/env perl
################################################################################
# Copyright (c) 2010-2011 Martin Scharrer <martin@scharrer-online.de>
# This is open source software under the GPL v3 or later.
#
# Converts a .sty file (LaTeX package) to .dtx format (documented LaTeX source),
# by surrounding macro definitions with 'macro' and 'macrocode' environments.
# The macro name is automatically inserted as an argument to the 'macro'
# environemnt.
# Code lines outside macro definitions are wrapped only in 'macrocode'
# environments. Empty lines are removed.
# The script is not thought to be fool proof and 100% accurate but rather
# as a good start to convert undocumented style file to .dtx files.
#
# Usage:
#    perl sty2dtx.pl infile [infile ...] outfile
# or
#    perl sty2dtx.pl < file.sty > file.dtx
#
#
# The following macro definitions are detected when they are at the start of a
# line (can be prefixed by \global, \long, \protected and/or \outer):
#   \def   \edef   \gdef   \xdef
#   \newcommand{\name}     \newcommand*{\name}
#   \newcommand\name       \newcommand*\name
#   \renewcommand{\name}   \renewcommand*{\name}
#   \renewcommand\name     \renewcommand*\name
#   \providecommand{\name} \providecommand*{\name}
#   \providecommand\name   \providecommand*\name
#   \@namedef{\name}       \@namedef\name
#
# The macro definition must either end at the same line or with a '}' on its own
# on a line.
#
# $Id$
################################################################################
use strict;
use warnings;

# Used as format string of printf so that the '%' must be doubled:
my $macrostart = <<'EOT';
%% \begin{macro}{\%s}
%%    \begin{macrocode}
EOT

# Printed normally:
my $macrostop = <<'EOT';
%    \end{macrocode}
% \end{macro}
%
EOT

my $macrocodestart = <<'EOT';
%    \begin{macrocode}
EOT

my $macrocodestop = <<'EOT';
%    \end{macrocode}
%
EOT

my $mode = 0;

# 0 = outside of macro or macrocode environments
# 1 = inside macro environment
# 2 = inside macrocode environment

# RegExs for macro names and defintion:
my $macroname = qr/[a-zA-Z\@:]+/;    # Add ':' for LaTeX3 style macros
my $definition = qr/
    ^                                                        # Begin of line (no whitespaces!)
     (
       (?:(?:\\global|\\long|\\protected|\\outer)\s*)*       # Prefixes (maybe with whitespace between them)
     )
    \\(
          [gex]?def \s* \\                                   # TeX definitions
        | (?:new|renew|provide)command\s* \*? \s* {? \s* \\  # LaTeX definitions
        | \@namedef{?                                        # Definition by name only
     )
     ($macroname)                                            # Macro name without backslash
     (.*)                                                    # Rest of line
    /xms;

# Last (but not only) argument is output file, except if it is '-' (=STDOUT)
if (@ARGV > 1) {
    my $outfile = pop;
    if ($outfile ne '-') {
        open (OUTPUT, '>', $outfile) or die ("Could not open output file '$outfile'!");
        select OUTPUT;
    }
}

while (<>) {
    # Test for macro definition command
    if (/$definition/) {
        my $pre  = $1 || "";    # before command
        my $cmd  = $2;          # definition command
        my $name = $3;          # macro name
        my $rest = $4;          # rest of line
        if ( $cmd =~ /command\*?{/ ) {
            $rest =~ s/^}//;    # handle '\newcommand{\name}
        }

        # Print end of environment, if one is open
        if ( $mode == 1 ) {
            # Happens only if closing brace is not on a line by its own.
            print $macrostop;
        }
        elsif ( $mode == 2 ) {
            print $macrocodestop;
        }

        # Print 'macro' environment with current line.
        printf $macrostart, $name;
        print $_;

        # Inside macro mode
        $mode = 1;

        # Test for one line definitions.
        # $pre is tested to handle '{\somecatcodechange\gdef\name{short}}' lines
        my $prenrest = $pre . $rest;
        if ( $prenrest =~ tr/{/{/ == $prenrest =~ tr/}/}/ ) {
            print $macrostop;
            # Outside mode
            $mode = 0;
        }
    }
    # A single '}' on a line ends a 'macro' environment
    elsif ($mode == 1 && /^}\s*$/) {
        print $_, $macrostop;
        $mode = 0;
    }
    # Remove empty lines (mostly between macros)
    elsif (/^$/) {
    }
    else {
        # If inside an environment
        if ($mode) {
            print;
        }
        else {
            # Start macrocode environment
            print $macrocodestart, $_;
            $mode = 2;
        }
    }
}

# Print end of environment, if one is open
if ( $mode == 1 ) {
    # Happens only if closing brace is not on a line by its own.
    print $macrostop;
}
elsif ( $mode == 2 ) {
    print $macrocodestop;
}

__END__

