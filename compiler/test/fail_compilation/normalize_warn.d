// REQUIRED_ARGS: -identifiers=UAX31 -normalization=warn -w

/*
TEST_OUTPUT:
---
fail_compilation\normalize_warn.d-mixin-17(17): Warning: Unnormalized identifier `s̀̕ͅe`
fail_compilation\normalize_warn.d-mixin-20(20): Warning: Unnormalized identifier `s̀̕ͅe`
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/

// all ccc's are in order (starters only), this needs to be ok
int sstarters;

// all non-starters are in order, only U+0315 is normalized the rest are maybes/no's, will error
mixin("int s\u0300\u0315\u0345e;");

// all non-starters are not in order, will error
mixin("int s\u0345\u0315\u0300e;");
