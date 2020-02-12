// EXTRA_SOURCES: extra-files/header1.d
// REQUIRED_ARGS: -o- -unittest -H -Hf${RESULTS_DIR}/compilable/testheader1.di -ignore
// PERMUTE_ARGS: -d -dw
// POST_SCRIPT: compilable/extra-files/header-postscript.sh

void main() {}
