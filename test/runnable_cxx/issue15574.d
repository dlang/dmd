/*
DISABLED: win

EXTRA_ARTIFACT: lib15574c.o = ${CC} -m${MODEL} -c -o $@ runnable_cxx/extra-files/lib15574.c

EXTRA_ARTIFACT: lib15574c.a = ar rcs $@ ${RESULTS_DIR}/runnable_cxx/lib15574c.o

EXTRA_ARTIFACT: lib15574d.a = ${DMD} -lib -of=$@ runnable_cxx/imports/lib15574.d

REQUIRED_ARGS: $@[2] -L-L${RESULTS_DIR}/runnable_cxx/ -L-l15574c
PERMUTE_ARGS:
*/

import imports.lib15574;

int main() {
    return testSquare() ? 0 : 1;
}
