struct sliceULong(ulong from, ulong to)
{
}

static assert(sliceULong!( 6 , 9 ).mangleof == "S10issue1272024__T10sliceULongVmi6Vmi9Z10sliceULong");
static assert(sliceULong!( 0 , 6 ).mangleof == "S10issue1272024__T10sliceULongVmi0Vmi6Z10sliceULong");
static assert(sliceULong!( 6L, 9L).mangleof == "S10issue1272024__T10sliceULongVmi6Vmi9Z10sliceULong");
static assert(sliceULong!( 0L, 6L).mangleof == "S10issue1272024__T10sliceULongVmi0Vmi6Z10sliceULong");
static assert(sliceULong!( 6u, 9L).mangleof == "S10issue1272024__T10sliceULongVmi6Vmi9Z10sliceULong");
static assert(sliceULong!( 0u, 6L).mangleof == "S10issue1272024__T10sliceULongVmi0Vmi6Z10sliceULong");
static assert(sliceULong!( 6u, 9u).mangleof == "S10issue1272024__T10sliceULongVmi6Vmi9Z10sliceULong");
static assert(sliceULong!( 0u, 6u).mangleof == "S10issue1272024__T10sliceULongVmi0Vmi6Z10sliceULong");

struct sliceInt(int from, int to)
{
}

static assert(sliceInt!( 6 , 9 ).mangleof == "S10issue1272021__T8sliceIntVii6Vii9Z8sliceInt");
static assert(sliceInt!( 0 , 6 ).mangleof == "S10issue1272021__T8sliceIntVii0Vii6Z8sliceInt");

struct sliceAny(T...)
{
}

static assert(sliceAny!( 6, 9 ).mangleof == "S10issue1272021__T8sliceAnyVii6Vii9Z8sliceAny");
static assert(sliceAny!( 0, 6 ).mangleof == "S10issue1272021__T8sliceAnyVii0Vii6Z8sliceAny");
static assert(sliceAny!( 6UL, 9UL).mangleof == "S10issue1272021__T8sliceAnyVmi6Vmi9Z8sliceAny");
static assert(sliceAny!( 0UL, 6UL).mangleof == "S10issue1272021__T8sliceAnyVmi0Vmi6Z8sliceAny");
static assert(sliceAny!( 6L, 9UL).mangleof == "S10issue1272021__T8sliceAnyVli6Vmi9Z8sliceAny");
static assert(sliceAny!( 0L, 6UL).mangleof == "S10issue1272021__T8sliceAnyVli0Vmi6Z8sliceAny");
