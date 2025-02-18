#
# i.ksh - initialize ksh for p.* routines
#
# Usage:	. a2z/bin/i.ksh		!!! from top level of disc !!!
#
# Written by Rich Morin, CFCL, January, 1992
#
# Public Domain - all uses allowed

PTF_BASE=`pwd`;			export PTF_BASE

if [ `echo [Aa]2[Zz]` = 'A2Z' ]; then
  PTF_CASE=UPPER;		export PTF_CASE
  PATH=$PTF_BASE/A2Z/BIN:$PATH
else
  PATH=$PTF_BASE/a2z/bin:$PATH
fi
