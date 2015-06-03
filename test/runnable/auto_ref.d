struct S { }

bool isLvalue(S s) {
    return false;
}

bool isLvalue(ref S s) {
    return true;
}

void oof(    S s) { }
void ofo(ref S s) { }
void foo(auto ref S s) { }

int bar(auto ref S s) { return 1; }
int bar(         S s) { return 3; }

int baw(auto ref S s) { return 1; }
int baw(     ref S s) { return 2; }

int bay(auto ref S s) { return 1; }
int bay(     ref S s) { return 2; }
int bay(         S s) { return 3; }

struct S1 { int n; }
struct S2 { this(int n) { } }

void baz(ref S1 s) { }
void vaz(ref S2 s) { }

bool testautoref()
{
    S s;

    assert(!isLvalue(S()));
    assert(isLvalue(s));

    // 'auto ref' can bind both lvalue and rvalue
    foo(s  );
    foo(S());

    // overload resolution between 'auto ref' and non-ref
    // 'auto ref' is always lesser matching.
    assert(bar(s  ) == 1);
    assert(bar(S()) == 3);

    // overload resolution between 'auto ref' and 'ref'
    // 'auto ref' is always lesser matching.
    assert(baw(s  ) == 2);
    assert(baw(S()) == 1);

    // overload resolution between 'auto ref', 'ref', and non-ref
    // 'auto ref' is always lesser matching, then *never matches anything*.
    assert(bay(s  ) == 2);
    assert(bay(S()) == 3);

    // keep right behavior: rvalues never matches to 'ref'
    static assert(!__traits(compiles, baz(S1(1))));
    static assert(!__traits(compiles, vaz(S2(1))));

    static assert(oof.mangleof == "_D8auto_ref3oofFS8auto_ref1SZv");
    static assert(ofo.mangleof == "_D8auto_ref3ofoFKS8auto_ref1SZv");
    static assert(foo.mangleof == "_D8auto_ref3fooFKKS8auto_ref1SZv");

    return true;
}

void main() {
    testautoref();
    static assert(testautoref());   // CTFE
} 