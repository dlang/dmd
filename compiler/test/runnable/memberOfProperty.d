extern(C) void printf(const char*, ...);

extern(C) void main() {
    int varB = :max;
    Context varS = :max;
    Enum varE = :End;
    Enum varF1 = functionReturn();
    Enum varF2 = identity(:Middle);
    printf("%d <> %d <> %d <> %d <> %d\n", varB, varS.value, varE, varF1, varF2);

    switch(varF1) {
        case :Start:
            static assert(!__traits(compiles, { const fail = :max; }));
            break;
        default:
            assert(0);
    }

    static assert(!__traits(compiles, { const fail = :max; }));
    static assert(!__traits(compiles, { Context fail = :max.min; }));
}

struct Context {
    int value;
    enum Context min = Context(int.min);
    enum Context max = Context(int.max);
}

enum Enum {
    Start,
    Middle,
    End
}

Enum functionReturn() {
    return :Start;
}

Enum identity(Enum input) {
    return input;
}
