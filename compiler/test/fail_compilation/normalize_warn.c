// REQUIRED_ARGS: -identifiers-importc=UAX31 -normalization-importc=warn -w

// Disable on posix, as we use gcc there and it'll do its own thing.
// Clang doesn't currently have normalization warning, so enable it there.
// Sppn only has c99 tables, so disable these tests for that
// DISABLED: win32omf linux freebsd openbsd

/*
TEST_OUTPUT:
---
fail_compilation\normalize_warn.c(22): Warning: Unnormalized identifier `s̀̕ͅe`
fail_compilation\normalize_warn.c(25): Warning: Unnormalized identifier `s̀̕ͅe`
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/

// all ccc's are in order (starters only), this needs to be ok
int sstarters;

// all non-starters are in order, only U+0315 is normalized the rest are maybes/no's, will error
int s\u0300\u0315\u0345e;

// all non-starters are not in order, will error
int s\u0345\u0315\u0300e;
