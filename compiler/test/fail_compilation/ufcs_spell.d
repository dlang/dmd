/*
TEST_OUTPUT:
---
fail_compilation/ufcs_spell.d(14): Error: no property `splitlines` for `s` of type `string`
fail_compilation/ufcs_spell.d(14):        did you mean function `splitLines`?
fail_compilation/ufcs_spell.d(15): Error: undefined identifier `splitlines`, did you mean function `splitLines`?
---
*/

string splitLines(string);

void main() {
    auto s = "red blue";
    auto r1 = s.splitlines;
    auto r2 = splitlines(s);
}
