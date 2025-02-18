#
# i.csh - initialize csh for p.* routines
#
# Usage:	source a2z/bin/i.csh	!!! from top level of disc !!!
#
# Written by Rich Morin, CFCL, January, 1992
#
# Public Domain - all uses allowed

setenv PTF_BASE `pwd`

if (`echo [Aa]2[Zz]` == 'A2Z') then
  setenv PTF_CASE UPPER
  set path = ( $PTF_BASE/A2Z/BIN $path)
else
  set path = ( $PTF_BASE/a2z/bin $path)
endif

rehash
