// REQUIRED_ARGS: -unittest -main

int i;

void hof1((ref int function()) fptr) { fptr()++; }
void hof2(ref (int function()) fptr) { fptr = ref () => i; }
void hof3(ref (ref int function())[] fptrs)
{
    static assert(__traits(isRef, fptrs));
    fptrs[0]() = 1;
}

ref int h       () => i;
ref int function() fptr = &h;

unittest
{
    hof1(&h);
    hof1(ref() => i);
    assert(i == 2);

    ref int function() fp = &h;
    fp()++;
    assert(i == 3);

    fptr()++;
    assert(i == 4);
}

alias Func = ref int function();
static assert(is(Func == typeof(&h)));

struct S
{
    int i;
    ref int get() => i;
}

unittest
{
    S s;
    ref int delegate() d = &s.get;
    d()++;
    assert(s.i == 1);
}

alias Del = ref int delegate();
static assert(is(Del == typeof(&S().get)));
