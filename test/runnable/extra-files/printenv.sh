# Small test to check whether the environment is propagated as expected
# (not intended stay, just checking in the CI)

if [ "$DFLAGS" != "" ]
then
    echo "DFLAGS = '$DFLAGS'"
    exit 1
fi

$DMD -conf= -m$MODEL $PIC_FLAG -I../../druntime/src -run runnable/printenv.d
