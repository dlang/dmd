// REQUIRED_ARGS: -identifiers-importc=UAX31 -normalization-importc=ignore

// Disable on posix, as we use gcc there and it'll do its own thing.
// Clang doesn't currently have normalization warning, so enable it there.
// Sppn only has c99 tables, so disable these tests for that
// DISABLED: win32omf linux freebsd openbsd

// all ccc's are in order (starters only), this needs to be ok
int sstarters;

// all non-starters are in order, only U+0315 is normalized the rest are maybes/no's, is in error
int s\u0300\u0315\u0345e;

// all non-starters are not in order, is in error
int s\u0345\u0315\u0300e;
