#!/bin/sh
#ident	"@(#)incl:bin/incl	3.1" 
###############################################################################
#
# C++ Standard Components, Release 3.0.
#
# Copyright (c) 1991, 1992 AT&T and Unix System Laboratories, Inc.
# Copyright (c) 1988, 1989, 1990 AT&T.  All Rights Reserved.
#
# THIS IS UNPUBLISHED PROPRIETARY SOURCE CODE OF AT&T and Unix System
# Laboratories, Inc.  The copyright notice above does not evidence
# any actual or intended publication of such source code.
#
###############################################################################

# Set this to where you keep your C++ standard include files.
CCSTDINCL=${CCSTDINCL-/usr/include/CC}

# Set <CCROOTDIR> to where you installed incl2.
INCL2=${INCL2-/CCROOTDIR/incl2}

# Set these to the locations of these tools on your machine.  
# For any tool you don't have, just set it to the empty string, 
# e.g., TPIC=
DAG=/tools/DAG/bin/dag		# dag graph drawing tool
TPIC=/usr/tools/ctex/bin/tpic 	# pic to tex converter
TEX=/usr/tools/ctex/bin/tex	# Knuth's TeX

# Set these to whatever number of inches you like.  It's the 
# default size of the inheritance graph.  If you change it 
# from 8.5x10, remember to change the manpage.
DEFAULTWIDTH=8.5
DEFAULTHEIGHT=10

###############################################################
# You shouldn't have to change anything below this line.
###############################################################

badargs=0
set -- `getopt Avlkxb:I:h:w:L:o: $*`
if [ $? -ne 0 ]
then	badargs=1
fi

boxname=graph
width=$DEFAULTWIDTH
height=$DEFAULTHEIGHT
base=inclout
parseopts=
vertical=0
wantps=0
wantdvi=0
wanttex=0
wantpic=0
wantdag=0
countlangs=
lang=

# parse the options
#
for i in $*
do	case $i in
	-x)	set -x
		shift;;
	-b)	case $2 in
			-*)	echo "incl: missing box name"; badargs=1; break;;
			*)	boxname=$2; shift; shift;;
		esac;;
	-L)	countlangs=x$countlangs
		lang=$2
		case $lang in
			ps)	wantps=1;;
			dvi)	wantdvi=1;;
			tex)	wanttex=1;;
			pic)	wantpic=1;;
			dag)	wantdag=1;;
			*)	echo "incl: unrecognized language -- $2"; badargs=1;;
		esac; shift; shift;;
	-h)	case $2 in 
			[0-9]*)	height=$2; shift; shift;;	# rudimentary error checking.  
								# should really check that $2 is a number.
			-*)	echo "incl: missing height"; badargs=1; break;;
			*)	echo "incl: bad height ($2)"; badargs=1; shift; shift;;
		esac;;
	-w)	case $2 in 
			[0-9]*)	width=$2; shift; shift;;
			-*)	echo "incl: missing width"; badargs=1; break;;
			*)	echo "incl: bad width ($2)"; badargs=1; shift; shift;;
		esac;;
	-o)	case $2 in
			-*)	echo "incl: missing base file name"; badargs=1; break;;
			*)	base=`echo $2 | sed 's/\.[^\.]*$//'`	# strip any extension.  
									# i will provide the appropriate extension(s).
		esac; shift; shift;;
	-[lkA])
		parseopts="$parseopts $i"; shift;;
	-v)	vertical=1; shift;;
	-I)	parseopts="$parseopts -I$2"; shift; shift;;
	--)	shift; break;;
	-*)	#echo "incl: illegal option $i (ignored)"; 
		shift;;
	esac
done

# -A is implicit if no languages are specified
if [ -z "$countlangs" ]
then	parseopts="$parseopts -A"
fi

parseopts="$parseopts -I$CCSTDINCL"

if [ $badargs -eq 1 ]
then
cat <<'End of cat'

usage: incl [-Aklv] [-L language] [-b boxname] [-o outputbase] [-w width] [-h height] [-I include-directory ] file ...

-A = produce ascii output in addition to output(s) specified by -L
-k = don't print <> or ""'s
-l = print full path names
-v = orient graph vertically

language can be any of {ps, tex, dvi, pic, dag}
multiple -L options are allowed
any extension on outputbase is ignored
height and width should be dimensionless inches (eg, -h5.2)

End of cat
exit 2
fi
	
# Check to see whether we have the tools necessary
# to produce output in the desired languages.
#
if [ -z "$DAG" ]
then	# on systems without dag, the user must explicitly
	# request dag code, since that's the only thing I
	# can generate.
	if [ $wantdag -eq 0 ]
	then	echo "Your system does not have dag."
		echo "I can only generate dag code."
		exit 2
	fi
	if [ $wantdvi -eq 1 -o $wanttex -eq 1 -o $wantps -eq 1 -o $wantpic -eq 1 ]
	then	echo "Your system does not have dag."
		echo "I'm ignoring -Lps, -Lpic, -Ltex, and -Ldvi."
		wantps=0
		wantpic=0
		wanttex=0
		wantdvi=0
	fi
fi
if [ -z "$TPIC" ]
then	if [ $wantdvi -eq 1 -o $wanttex -eq 1 ]
	then	echo "Your system does not have tpic."
		if [ $wantdvi -eq 1 -a $wanttex -eq 1 ]
		then	echo "I'm ignoring the -Ltex and -Ldvi switches."
		elif [ $wantdvi -eq 1 ] 
		then	echo "I'm ignoring the -Ldvi switch."
		else	echo "I'm ignoring the -Ltex switch."
		fi
		wantdvi=0
		wanttex=0
	fi
fi
if [ -z "$TEX" -a $wantdvi -eq 1 ]
then	echo "Your system does not have TeX."
	echo "I'm ignoring the -Ldvi switch."
	wantdvi=0
fi

# keeps track of the files that should be removed before exiting.
#
deleteEm=$base.tmp
trap 'rm -f $deleteEm; exit' 1 2 3 15

							# create the dag source no matter what (everyone needs it).
if [ $wantdag -eq 0 ]
then	deleteEm="$deleteEm $base.dag"
fi
rm -f $base.dag
echo >$base.dag

if [ $vertical -eq 1 ]
then	if [ -z "$width" ]
	then	PREFIX=".GS"
	else	PREFIX=".GS $width $height"
	fi
else	if [ -z "$width" ]
	then	PREFIX=".GR"
	else	PREFIX=".GR $width $height"
	fi
fi

# analyze all the input files.
# unlike HIER, we process them all with one run of incl2.

files=

for file in $*
do	case $file in 
	*.dag)	sed '/^\.G[SRE].*$/d' $file >>$base.dag;;		# Append it after stripping out . directives.
	*) files="$files $file";; 
	esac
done

$INCL2 $parseopts -d $base.dag $files 

sort $base.dag | uniq >$base.tmp	# remove duplicate edges
echo $PREFIX >$base.dag
cat $base.tmp >>$base.dag
rm $base.tmp
echo ".GE" >>$base.dag			# this is the final version of the .dag output

deleteEm="$deleteEm $$.dag"
sed 's/#.*//' $base.dag >$$.dag					# create a dag-able dag source

if [ $wantps -eq 1 ]						# then create the postscript source
then	$DAG -Tps $$.dag >$base.ps
fi

if [ $wantpic -eq 1 -o $wanttex -eq 1 -o $wantdvi -eq 1 ]	# then create the pic source
then	if [ $wantpic -eq 0 ]
	then	deleteEm="$deleteEm $base.pic"
	fi
	$DAG $$.dag >$base.pic					
fi

rm -f $$.dag

if [ $wanttex -eq 1 -o $wantdvi -eq 1 ]				# then create the tex source
then	if [ $wanttex -eq 0 ]
	then	deleteEm="$deleteEm $base.tex"
	fi
	sed -e '/^\.lf.*/d' -e '/^\.ps$/d' <$base.pic >$base.tmp	# pic suitable for tpic
	$TPIC $base.tmp	 						# tex but with free underscores in identifier names,
									# and box name = "graph"
	mv $base.tmp.tex $base.tmp
	sed -e "s/\\\csname graph/\\\csname $boxname/"		\
		-e "s/\\\insc@unt\\\graph/\\\insc@unt\\\\$boxname/" 	\
		-e "s/\\\setbox\\\graph/\\\setbox\\\\$boxname/" 	\
		-e 's/_/\\_/g' <$base.tmp >$base.tex			# tex
	rm -f $base.tmp
fi


if [ $wantdvi -eq 1 ]						# then create the dvi source
then	if [ $wantdvi -eq 0 ]
	then	deleteEm="$deleteEm $base.dvi $base.log"
	fi
	cp $base.tex $base.tmp
	echo "\centerline{\box\\$boxname}" >>$base.tex
	echo "\end" >>$base.tex
	$TEX $base
	mv $base.tmp $base.tex
	rm -f $base.log
fi

# Delete unwanted files.
#
if [ ! -z "$deleteEm" ]
then	rm -f $deleteEm
fi
