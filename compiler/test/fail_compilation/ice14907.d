/*
TEST_OUTPUT:
----
fail_compilation/ice14907.d(28): Error: struct `ice14907.S(int v = S)` recursive template expansion
struct S(int v = S) {}
^
fail_compilation/ice14907.d(33):        while looking for match for `S!()`
    S!() s;     // OK <- ICE
    ^
fail_compilation/ice14907.d(29): Error: template `ice14907.f(int v = f)()` recursive template expansion
void f(int v = f)() {}
     ^
fail_compilation/ice14907.d(34):        while looking for match for `f!()`
    f!()();     // OK <- ICE
    ^
fail_compilation/ice14907.d(29): Error: template `ice14907.f(int v = f)()` recursive template expansion
void f(int v = f)() {}
     ^
fail_compilation/ice14907.d(35): Error: template `f` is not callable using argument types `!()()`
    f();        // OK <- ICE
     ^
fail_compilation/ice14907.d(29):        Candidate is: `f(int v = f)()`
void f(int v = f)() {}
     ^
----
*/

struct S(int v = S) {}
void f(int v = f)() {}

void main()
{
    S!() s;     // OK <- ICE
    f!()();     // OK <- ICE
    f();        // OK <- ICE
}
