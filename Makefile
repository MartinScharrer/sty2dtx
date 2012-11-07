NAME=sty2dtx

LATEX=pdflatex

SCRIPT=${NAME}.pl

define PREAMBLE
\documentclass[a4paper]{article}\
\usepackage{hyperref}\
\setcounter{secnumdepth}{0}\
\setlength{\parindent}{0pt}\
\title{\Huge Manual page for \textsf{sty2dtx}}\
\author{\Large Martin Scharrer\\[\medskipamount]\href{mailto:martin@scharrer-online.de}{martin@scharrer-online.de}}\
\date{2012/11/07 -- v2.3}\
\begin{document}\
\maketitle
endef

define POSTAMBLE
\end{document}
endef

.PHONY: doc pdf man clean tex

all: doc

doc: pdf man README

tex: ${NAME}.tex

%.tex: %.pl Makefile
	@pod2latex -full -preamble '${PREAMBLE}' -postamble '${POSTAMBLE}'  $<

pdf: ${NAME}.pdf

%.pdf: %.tex Makefile
	latexmk -pdf $<

man: ${NAME}.1

%.1: %.pl
	@pod2man $< > $@

clean:
	${RM} ${NAME}.pdf ${NAME}.1 ${NAME}.tex README ${NAME}.log ${NAME}.fls ${NAME}.out ${NAME}.fdb_latexmk ${NAME}.aux ${NAME}.zip

README: ${SCRIPT}
	pod2text $< > $@

ctanify: zip

zip: pdf man README
	zip ${NAME}.zip ${SCRIPT} ${NAME}.pdf ${NAME}.1 README

