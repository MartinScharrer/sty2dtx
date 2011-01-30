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

my $macrodescription = <<'EOT';
%%
%% \DescribeMacro{\%s}
%%
EOT

my $envdescription = <<'EOT';
%%
%% \DescribeEnv{%s}
%%
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

my @USAGE;  # Store usage section
my @IMPL;   # Store implementation section

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
        print STDERR $name, "\n";
        if ($name =~ /^[a-z]+$/i) {
            push @USAGE, sprintf ($macrodescription, $name);
        }

        # Print end of environment, if one is open
        if ( $mode == 1 ) {
            # Happens only if closing brace is not on a line by its own.
            push @IMPL, $macrostop;
        }
        elsif ( $mode == 2 ) {
            push @IMPL, $macrocodestop;
        }

        # Print 'macro' environment with current line.
        push @IMPL, sprintf( $macrostart, $name );
        push @IMPL, $_;

        # Inside macro mode
        $mode = 1;

        # Test for one line definitions.
        # $pre is tested to handle '{\somecatcodechange\gdef\name{short}}' lines
        my $prenrest = $pre . $rest;
        if ( $prenrest =~ tr/{/{/ == $prenrest =~ tr/}/}/ ) {
            push @IMPL, $macrostop;
            # Outside mode
            $mode = 0;
        }
    }
    # A single '}' on a line ends a 'macro' environment
    elsif ($mode == 1 && /^}\s*$/) {
        push @IMPL, $_, $macrostop;
        $mode = 0;
    }
    # Remove empty lines (mostly between macros)
    elsif (/^$/) {
    }
    else {
        # If inside an environment
        if ($mode) {
            push @IMPL, $_;
        }
        else {
            # Start macrocode environment
            push @IMPL, $macrocodestart, $_;
            $mode = 2;
        }
    }
}

# Print end of environment, if one is open
if ( $mode == 1 ) {
    # Happens only if closing brace is not on a line by its own.
    push @IMPL, $macrostop;
}
elsif ( $mode == 2 ) {
    push @IMPL, $macrocodestop;
}

my %vars = (
    IMPLEMENTATION => join ('', @IMPL),
    USAGE          => join ('', @USAGE),
);

while (<DATA>) {
    s/<\+([^+]+)\+>\n?/exists $vars{$1} ? $vars{$1} : "<+$1+>"/eg;
    print;
}

use Data::Dumper;
print STDERR Dumper \@USAGE;

#
# The template for the DTX file.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The '<+var+>' still was choosen because it is used by the latex suite for Vim.
# Therfore all variables which are not expanded are easily accessible to the
# user using a certain feature in the latex suite.
#
__DATA__
% \iffalse meta-comment
%
% Copyright (C) <+year+> by <+author+> <<+email+>>
% -------------------------------------------------------
% This work may be distributed and/or modified under the
% conditions of the LaTeX Project Public License, either version 1.3
% of this license or (at your option) any later version.
% The latest version of this license is in
%   http://www.latex-project.org/lppl.txt
% and version 1.3 or later is part of all distributions of LaTeX
% version 2005/12/01 or later.
%
% This work has the LPPL maintenance status `maintained'.
%
% The Current Maintainer of this work is <+maintainer+>.
%
% This work consists of the files <+file+>.dtx and <+file+>.ins
% and the derived file <+file+>.sty.
%
% \fi
%
% \iffalse
%<*driver>
\ProvidesFile{skeleton.dtx}
%</driver>
%<package>\NeedsTeXFormat{LaTeX2e}[1999/12/01]
%<package>\ProvidesPackage{<+file+>}
%<*package>
    [<+vdate+> <+version+> <+description+>]
%</package>
%
%<*driver>
\documentclass{ltxdoc}
\usepackage{<+file+>}[<+vdate+>]
\EnableCrossrefs
\CodelineIndex
\RecordChanges
\begin{document}
  \DocInput{<+file+>.dtx}
  \PrintChanges
  \PrintIndex
\end{document}
%</driver>
% \fi
%
% \CheckSum{0}
%
% \CharacterTable
%  {Upper-case    \A\B\C\D\E\F\G\H\I\J\K\L\M\N\O\P\Q\R\S\T\U\V\W\X\Y\Z
%   Lower-case    \a\b\c\d\e\f\g\h\i\j\k\l\m\n\o\p\q\r\s\t\u\v\w\x\y\z
%   Digits        \0\1\2\3\4\5\6\7\8\9
%   Exclamation   \!     Double quote  \"     Hash (number) \#
%   Dollar        \$     Percent       \%     Ampersand     \&
%   Acute accent  \'     Left paren    \(     Right paren   \)
%   Asterisk      \*     Plus          \+     Comma         \,
%   Minus         \-     Point         \.     Solidus       \/
%   Colon         \:     Semicolon     \;     Less than     \<
%   Equals        \=     Greater than  \>     Question mark \?
%   Commercial at \@     Left bracket  \[     Backslash     \\
%   Right bracket \]     Circumflex    \^     Underscore    \_
%   Grave accent  \`     Left brace    \{     Vertical bar  \|
%   Right brace   \}     Tilde         \~}
%
%
% \changes{<+version+>}{<+vdate+>}{Converted to DTX file}
%
% \DoNotIndex{\newcommand,\newenvironment}
%
% \GetFileInfo{<+file+>.dtx}
% \title{The \textsf{<+file+>} package}
% \author{<+author+> \\ \url{<+email+>}}
% \date{\fileversion from \filedate}
%
% \maketitle
%
% \section{Introduction}
%
% Put text here.
%
% \section{Usage}
%
% Put text here.
%
<+USAGE+>
%
% \StopEventually{}
%
% \section{Implementation}
%
<+IMPLEMENTATION+>
%
% \Finale
\endinput
