// https://issues.dlang.org/show_bug.cgi?id=20951

// This test fails if DMD is linked against the DigitalMars C runtime
// (non-standard strtod and strtof implementations).
// DISABLED: win

static assert(1.448997445238699 == 0x1.72f17f1f49aadp0);
static assert(2075e23 == 0xaba3d58a1f1a98p+32);
