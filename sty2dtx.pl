#!/usr/bin/perl
################################################################################
# Copyright (c) 2009 Martin Scharrer <martin@scharrer-online.de>
# This is open source software under the GPL v3 or later.
#
# $Id$
################################################################################
use strict; 
use warnings;

my $macrostart = <<'EOT';
%% \begin{macro}{%s}
%%    \begin{macrocode}
EOT

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

my $closematter = "";
my $inmacro = 0;

while (<>) {
   if (/^(\\expandafter|\\\@firstoftwo{)?\\[exg]?(def|newcommand\*?{?)(\\[a-zA-Z@]+)(.*)/) {
       my $pre  = $1 || "";
       my $cmd  = $2;
       my $name = $3;
       my $rest = $4;
       if ($cmd =~ /^newcommand.*{/) {
          $rest =~ s/^}//;
       }
       my $prerest = $pre.$rest;
       if ($prerest =~ tr/{/{/ == $prerest =~ tr/}/}/) {
          print $closematter; $closematter = "";
          printf $macrostart, $name;
          print $_,$macrostop;
       }
       else {
          print $closematter; $closematter = "";
          printf $macrostart, $name;
          print $_;
       }
       $inmacro=1;
   }
   elsif (/^}$/) {
       print $_,$macrostop;
       $inmacro=0;
   }
   elsif (/^$/) {
   }
   else {
       if ($closematter||$inmacro) {
         print;
       } else {
         print $macrocodestart, $_;
         $closematter = $macrocodestop;
       }
   }
}

__END__

