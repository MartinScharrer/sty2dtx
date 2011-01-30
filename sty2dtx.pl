#!/usr/bin/env perl
use strict;
use warnings;
################################################################################
# $Id$
################################################################################
my $COPYRIGHT = << 'EOT';
  Copyright (c) 2010-2011 Martin Scharrer <martin@scharrer-online.de>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

EOT
################################################################################
my $DESCRIPTION = << 'EOT';
  Converts a .sty filebase (LaTeX package) to .dtx format (documented LaTeX source),
  by surrounding macro definitions with 'macro' and 'macrocode' environments.
  The macro name is automatically inserted as an argument to the 'macro'
  environemnt.
  Code lines outside macro definitions are wrapped only in 'macrocode'
  environments. Empty lines are removed.
  The script is not thought to be fool proof and 100% accurate but rather
  as a good start to convert undocumented style filebase to .dtx files.

  Usage:
     perl sty2dtx.pl infile [infile ...] outfile
  or
     perl sty2dtx.pl < filebase.sty > filebase.dtx


  The following macro definitions are detected when they are at the start of a
  line (can be prefixed by \global, \long, \protected and/or \outer):
    \def   \edef   \gdef   \xdef
    \newcommand{\name}     \newcommand*{\name}
    \newcommand\name       \newcommand*\name
    \renewcommand{\name}   \renewcommand*{\name}
    \renewcommand\name     \renewcommand*\name
    \providecommand{\name} \providecommand*{\name}
    \providecommand\name   \providecommand*\name
    \@namedef{\name}       \@namedef\name

  The following environment definitions are detected when they are at the start
  of a line:
    \newenvironment{name}  \renewenvironemnt{name}  \provideenvironment{name}

  The macro and environment definition must either end at the same line or with
  a '}' on its own on a line.

EOT
################################################################################
my $VERSION = substr('$Date$', 7, 10);
$VERSION =~ tr/-/\//;
my $TITLE = << "EOT";
  sty2dtx -- Converts a LaTeX .sty file to a documented .dtx file
  Version: $VERSION
EOT

sub usage {
    print << "EOT";
sty2dtx.pl [<options>] [--<VAR>=<VALUE> ...] [--] [<infile> ...] [<outfile>]
Version: $VERSION
EOT
    print << 'EOT';
Files:
  * can be '-' for STDIN or STDOUT, which is the default if no files are given
  * multiple input files are merged to one output file

Variables:
  can be defined using --<VAR>=<VALUE> or --<VAR> <VALUE> and will be used for
  substitutions in the template file.
  Common variables:
      author, email, maintainer, year (for copyright),
      version, date, description (of package/class),
      type (either 'package' default or 'class'),
      filebase (automatically set from output or input file name),

Options:
  -h            : Print this help text
  -H            : Print extended help
  -V            : Print version and copyright
  -t <template> : Use this file as template instead of the default one
  -e <file>     : Export default template to file and exit

Examples:
    sty2dtx.pl < infile > outfile
    sty2dtx.pl --author Me --email me@there.com mypkg.sty mypkg.dtx
    sty2dtx.pl --type class mycls.sty mycls.dtx

EOT
    exit (0);
}


# Used as format string of printf so that the '%' must be doubled:
my $macrostart = <<'EOT';
%% \begin{macro}{\%s}
%%    \begin{macrocode}
EOT

my $environmentstart = <<'EOT';
%% \begin{environment}{%s}
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

my $environmentstop = <<'EOT';
%    \end{macrocode}
% \end{environment}
%
EOT

my $macrocodestart = <<'EOT';
%    \begin{macrocode}
EOT

my $macrocodestop = <<'EOT';
%    \end{macrocode}
%
EOT

my $USAGE;  # Store macro names for usage section
my $IMPL;   # Store implementation section

my $mode = 0;
# 0 = outside of macro or macrocode environments
# 1 = inside macro environment
# 2 = inside macrocode environment

# RegExs for macro names and defintion:
my $rmacroname = qr/[a-zA-Z\@:]+/;    # Add ':' for LaTeX3 style macros
my $rusermacro = qr/[a-zA-Z]+/;       # Macros intended for users
my $rmacrodef = qr/
    ^                                                        # Begin of line (no whitespaces!)
     (
       (?:(?:\\global|\\long|\\protected|\\outer)\s*)*       # Prefixes (maybe with whitespace between them)
     )
    \\(
          [gex]?def \s* \\                                   # TeX definitions
        | (?:new|renew|provide)command\s* \*? \s* {? \s* \\  # LaTeX definitions
        | \@namedef{?                                        # Definition by name only
     )
     ($rmacroname)                                           # Macro name without backslash
     \s* }?                                                  # Potential closing brace
     (.*)                                                    # Rest of line
    /xms;

my $renvdef = qr/
    ^                                                        # Begin of line (no whitespaces!)
     \\(
        (?:new|renew|provide)environment\s* { \s*            # LaTeX definitions
     )
     ($rmacroname)                                           # Environment names follow same rules as macro names
     \s* }                                                   # closing brace
     (.*)                                                    # Rest of line
    /xms;


# Print end of environment, if one is open
sub close_env {
    if ( $mode == 1 ) {
        # Happens only if closing brace is not on a line by its own.
        $IMPL .= $macrostop;
    }
    elsif ( $mode == 2 ) {
        $IMPL .= $macrocodestop;
    }
    elsif ( $mode == 3 ) {
        $IMPL .= $environmentstop;
    }
}

my @files;
my %vars = ( type => 'package', class => 'ltxdoc' );

# Handle options
sub option {
    my $opt = shift;
    if ($opt eq 'h') {
        usage();
    }
    elsif ($opt eq 'H') {
        print $TITLE;
        print "\n";
        print $DESCRIPTION;
        exit (0);
    }
    elsif ($opt eq 't') {
        close (DATA);
        my $templ = shift @ARGV;
        open (DATA, '<', $templ) or die "Couldn't open template file '$templ'\n";
    }
    elsif ($opt eq 'e') {
        my $templ = shift @ARGV;
        open (TEMPL, '>', $templ) or die "Couldn't open new template file '$templ'\n";
        print TEMPL <DATA>;
        close (TEMPL);
        print STDERR "Exported default template to file '$templ'\n";
        exit (0);
    }
    elsif ($opt eq 'V') {
        print $TITLE;
        print "\n";
        print $COPYRIGHT;
        exit (0);
    }
}

################################################################################
# Parse arguments
while (@ARGV) {
    my $arg = shift;
    # '--' Marks rest of arguments as files
    if ($arg eq '--' ) {
        push @files, @ARGV;
        last;
    }
    # Options and variables
    elsif ($arg =~ /^(-+)(.+)$/ ) {
        my $dashes = $1;
        my $name   = $2;
        # Single dash => option
        if (length($dashes) == 1) {
            foreach my $opt (split //, $name) {
                option($opt);
            }
        }
        # Douple Dash => Variable
        # Form "--var=value"
        elsif ($name =~ /^([^=]+)=(.*)$/) {
                $vars{lc($1)} = $2;
        }
        # Form "--var value"
        else {
            $vars{lc($name)} = shift;
        }
    }
    # Files
    else {
        push @files, $arg;
    }
}


# Last (but not only) argument is output filebase, except if it is '-' (=STDOUT)
if (@files > 1) {
    my $outfile = pop @files;
    if ($outfile ne '-') {
        open (OUTPUT, '>', $outfile) or die ("Could not open output filebase '$outfile'!");
        select OUTPUT;
    }
    $vars{filebase} = substr($outfile, 0, rindex($outfile, '.'));
}
elsif (@files == 1) {
    my $infile = $files[0];
    $vars{filebase} = substr($infile, 0, rindex($infile, '.'));
}


################################################################################
# Read input files
@ARGV = @files;
while (<>) {
    # Test for macro definition command
    if (/$rmacrodef/) {
        my $pre  = $1 || "";    # before command
        my $cmd  = $2;          # definition command
        my $name = $3;          # macro name
        my $rest = $4;          # rest of line

        # Add to usage section if it is a user level macro
        if ($name =~ /^$rusermacro$/i) {
            $USAGE .= sprintf ($macrodescription, $name);
        }

        close_env();

        # Print 'macro' environment with current line.
        $IMPL .= sprintf( $macrostart, $name );
        $IMPL .= $_;

        # Inside macro mode
        $mode = 1;

        # Test for one line definitions.
        # $pre is tested to handle '{\somecatcodechange\gdef\name{short}}' lines
        my $prenrest = $pre . $rest;
        if ( $prenrest =~ tr/{/{/ == $prenrest =~ tr/}/}/ ) {
            $IMPL .= $macrostop;
            # Outside mode
            $mode = 0;
        }
    }
    # Test for environment definition command
    elsif (/$renvdef/) {
        my $cmd  = $1;          # definition command
        my $name = $2;          # macro name
        my $rest = $3;          # rest of line

        # Add to usage section if it is a user level environment
        # Can use the same RegEx as for macro names
        if ($name =~ /^$rusermacro$/i) {
            $USAGE .= sprintf ($envdescription, $name);
        }

        close_env();

        # Print 'environment' environment with current line.
        $IMPL .= sprintf( $environmentstart, $name );
        $IMPL .= $_;

        # Inside environment mode
        $mode = 3;

        # Test for one line definitions.
        my $nopen  = ($rest =~ tr/{/{/);
        if ( $nopen >= 2 && $nopen == ($rest =~ tr/}/}/) ) {
            $IMPL .= $environmentstop;
            # Outside mode
            $mode = 0;
        }
    }
    # A single '}' on a line ends a 'macro' environment in macro mode
    elsif ($mode == 1 && /^}\s*$/) {
        $IMPL .= $_ . $macrostop;
        $mode = 0;
    }
    # A single '}' on a line ends a 'environemnt' environment in environment
    # mode
    elsif ($mode == 3 && /^}\s*$/) {
        $IMPL .= $_ . $environmentstop;
        $mode = 0;
    }
    # Remove empty lines (mostly between macros)
    elsif (/^$/) {
    }
    else {
        # If inside an environment
        if ($mode) {
            $IMPL .= $_;
        }
        else {
            # Start macrocode environment
            $IMPL .= $macrocodestart . $_;
            $mode = 2;
        }
    }
}

close_env();

################################################################################
# Write output file
$vars{IMPLEMENTATION} = $IMPL;
$vars{USAGE}          = $USAGE;
$vars{type}           = "\L$vars{type}";
$vars{Type}           = "\L\u$vars{type}";

while (<DATA>) {
    # Substitute template variables
    s/<\+([^+]+)\+>\n?/exists $vars{$1} ? $vars{$1} : "<+$1+>"/eg;
    print;
}

exit(0)

################################################################################
# Write output file
# The template for the DTX filebase.
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
% This work consists of the files <+filebase+>.dtx and <+filebase+>.ins
% and the derived filebase <+filebase+>.sty.
%
% \fi
%
% \iffalse
%<*driver>
\ProvidesFile{<+filebase+>.dtx}
%</driver>
%<<+type+>>\NeedsTeXFormat{LaTeX2e}[1999/12/01]
%<<+type+>>\Provides<+Type+>{<+filebase+>}
%<*<+type+>>
    [<+date+> <+version+> <+description+>]
%</<+type+>>
%
%<*driver>
\documentclass{ltxdoc}
\usepackage{<+filebase+>}[<+date+>]
\EnableCrossrefs
\CodelineIndex
\RecordChanges
\begin{document}
  \DocInput{<+filebase+>.dtx}
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
% \changes{<+version+>}{<+date+>}{Converted to DTX filebase}
%
% \DoNotIndex{\newcommand,\newenvironment}
%
% \GetFileInfo{<+filebase+>.dtx}
% \title{The \textsf{<+filebase+>} package}
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
% \iffalse
%<*<+type+>>
% \fi
%
<+IMPLEMENTATION+>
%
% \iffalse
%</<+type+>>
% \fi
%
% \Finale
\endinput
