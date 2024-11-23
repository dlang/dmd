// https://issues.dlang.org/show_bug.cgi?id=3737
/*
TEST_OUTPUT:
---
fail_compilation/fail344.d(34): Error: undefined identifier `Q`
        enum bool Alike = Q == V.garbage;
                          ^
fail_compilation/fail344.d(34): Error: undefined identifier `Q`
        enum bool Alike = Q == V.garbage;
                          ^
fail_compilation/fail344.d(34): Error: undefined identifier `V`
        enum bool Alike = Q == V.garbage;
                               ^
fail_compilation/fail344.d(37):        while evaluating: `static assert(Alike!(SIB!(crayon)))`
        static assert(Alike!(SIB!(crayon)));
        ^
fail_compilation/fail344.d(37): Error: template instance `fail344.SIB!(crayon).SIB.Alike!(SIB!(crayon))` error instantiating
        static assert(Alike!(SIB!(crayon)));
                      ^
fail_compilation/fail344.d(37):        while evaluating: `static assert(Alike!(SIB!(crayon)))`
        static assert(Alike!(SIB!(crayon)));
        ^
fail_compilation/fail344.d(42): Error: template instance `fail344.SIB!(crayon).SIB.opDispatch!"E"` error instantiating
      SIB!(SIB!(crayon).E)(3.0);
      ^
---
*/

int crayon;

struct SIB(alias junk)
{
    template Alike(V) {
        enum bool Alike = Q == V.garbage;
    }
    void opDispatch(string s)() {
        static assert(Alike!(SIB!(crayon)));
    }
}

void main() {
      SIB!(SIB!(crayon).E)(3.0);
}
