// REQUIRED_ARGS: -identifiers=UAX31 -normalization=ignore

// all ccc's are in order (starters only), this needs to be ok
int sstarters;

// all non-starters are in order, only U+0315 is normalized the rest are maybes/no's, is in error
mixin("int s\u0300\u0315\u0345e;");

// all non-starters are not in order, is in error
mixin("int s\u0345\u0315\u0300e;");
