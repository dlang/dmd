// REQUIRED_ARGS: -inline
// PERMUTE_ARGS: -O

// Array-fill register allocation must not overwrite live register variables.
// An assertion-enabled compiler is needed to expose this regression.
template AliasSeq(T...) { alias AliasSeq = T; }

pragma(inline, false)
size_t twoValue() { return 2; }

void consume(A, B, C)(A, B, C) {}

struct Range
{
    size_t[1] length;
    ubyte padding;
}

struct View
{
    alias Fields = AliasSeq!(size_t[], ptrdiff_t[2]);
    Fields fields;
    size_t base;

    // Initializing the one-element array from a scalar uses array-fill code.
    Range opSlice(size_t dim)(size_t, size_t end) { return Range(end); }

    auto opIndex(A...)(A args)
    {
        size_t offset;
        auto parts = Fields.init;
        foreach (i, arg; args)
            offset += fields[1][i];
        return View(parts, base + offset);
    }
}

void main()
{
    auto two = twoValue();
    ulong[] a, b;
    View c, r;
    consume(a, b, r[3, 0 .. two]);
    c[3, 0 .. two] == r[3, 0];
}
