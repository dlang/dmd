// REQUIRED_ARGS: -o- -H -Hf${RESULTS_DIR}/compilable/testheader12567b.di
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/header-postscript.sh

deprecated("message") module header12567b;

void main() {}
