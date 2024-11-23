/*
TEST_OUTPUT:
---
fail_compilation/ice13459.d(18): Error: undefined identifier `B`
    auto opSlice() { return B; }
                            ^
fail_compilation/ice13459.d(24): Error: none of the overloads of `opSlice` are callable using argument types `(int, int)`
    foreach (fi; df[0..0]) {}
                   ^
fail_compilation/ice13459.d(17):        Candidate is: `ice13459.A.opSlice() const`
    auto opSlice() const {}
         ^
---
*/
struct A
{
    auto opSlice() const {}
    auto opSlice() { return B; }
}

void main()
{
    auto df = A();
    foreach (fi; df[0..0]) {}
}
