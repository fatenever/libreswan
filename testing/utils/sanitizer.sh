#!/bin/bash
set -eu

utilsdir=$(dirname $(readlink -f $0))
testingdir=$(dirname $utilsdir)
fixupdir=$testingdir/sanitizers

# cleanup the given console output

if test $# -lt 1; then
    cat <<EOF 1>&2
Usage:

    $0 <console.verbose.txt> [ <test-directory> [ <fixup-directory> ... ] ]

Cleans up the file <console.verbose.txt> using fixup scripts specified
by testparams.sh (or default-testparams.sh).  The result is written to
STDOUT.

<test-directory> specifies the test parameters directory.  By default,
<test-directory> is determined using the absolute path to
<console.verbose.txt>.  Typically required when the output file
<console.verbose.txt> is not under OUTPUT/ in the build tree.

<fixup.directory> ... is a list of directories containg the fixup
scripts.  By default:
  $fixupdir
is used.

EOF
    exit 1
fi

# <console.verbose.txt>
if test "x$1" = "x-"; then
    input=- ; shift
else
    input=$(readlink -f $1) ; shift
    if test ! -r "$input"; then
	echo "console.verbose.txt file not found: $input" 1>&2
	exit 1
    fi
    case "$input" in
	*.console.verbose.txt) ;;
	*) echo "expecting suffix .console.verbose.txt: $input" 1>&2 ; exit 1 ;;
    esac
fi

# <test-directory>
if test $# -gt 0; then
    testdir=$(readlink -f $1) ; shift
elif test "x$input" != "x-" ; then
    testdir=$(dirname $(dirname $input))
else
    echo "No <test-directory> specified (and console is '-')" 1>&2
    exit 1
fi

# <fixups-dir> ...
if test $# -gt 0; then
    :
else
    set "$fixupdir"
fi

# get REF_CONSOLE_FIXUPS
if [ -f $testdir/testparams.sh ]; then
    # testparams.sh expects to be sourced from its directory,
    # expecting to be able to include the relative pathed
    # ../../default-testparams.sh
    pushd $testdir
    . ./testparams.sh
    popd
else
    . $testingdir/default-testparams.sh
fi
if test "$REF_CONSOLE_FIXUPS" = ""; then
    echo "\$REF_CONSOLE_FIXUPS empty" 1>&2 ; exit 1
fi

cleanups="cat $input"
# expand wildcards?
for fixup in `echo $REF_CONSOLE_FIXUPS`; do
    cleanup=
    # Parameter list contains fixup directories.
    for fixupdir in "$@" ; do
	if test -f $fixupdir/$fixup ; then
	    case $fixup in
		*.sed) cleanup="sed -f $fixupdir/$fixup" ;;
		*.pl)  cleanup="perl $fixupdir/$fixup" ;;
		*.awk) cleanup="awk -f $fixupdir/$fixup" ;;
		*) echo "Unknown fixup type: $fixup" 1>&2 ; exit 1 ;;
	    esac
	    break
	fi
    done
    if test -z "$cleanup" ; then
	echo "Fixup '$fixup' not found in $@" 1>&2 ; exit 1
    fi
    cleanups="$cleanups | $cleanup"
done

eval $cleanups