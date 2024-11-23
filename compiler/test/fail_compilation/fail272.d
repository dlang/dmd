/*
TEST_OUTPUT:
---
fail_compilation/fail272.d(13): Error: circular reference to variable `fail272.Ins!(Ins).Ins`
template Ins(alias x) { const Ins = Ins!(Ins); }
                                    ^
fail_compilation/fail272.d(14): Error: template instance `fail272.Ins!(Ins)` error instantiating
alias Ins!(Ins) x;
      ^
---
*/

template Ins(alias x) { const Ins = Ins!(Ins); }
alias Ins!(Ins) x;
