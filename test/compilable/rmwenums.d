// PERMUTE_ARGS:

enum X { a, b, c };

void main()
{
    X x;
    static assert(!__traits(compiles, x += 1));
    static assert(!__traits(compiles, x -= 1));
    static assert(!__traits(compiles, x *= 1));
    static assert(!__traits(compiles, x /= 1));
    static assert(!__traits(compiles, x %= 1));
    static assert(!__traits(compiles, x <<= 1));
    static assert(!__traits(compiles, x >>= 1));
    static assert(!__traits(compiles, x >>>= 1));
    static assert(!__traits(compiles, x &= 1));
    static assert(!__traits(compiles, x |= 1));
    static assert(!__traits(compiles, x ^= 1));
    static assert(!__traits(compiles, x ~= 1));
    static assert(!__traits(compiles, x ^^= 1));
    static assert(!__traits(compiles, x++));
    static assert(!__traits(compiles, x--));
    static assert(!__traits(compiles, ++x));
    static assert(!__traits(compiles, --x));
}
