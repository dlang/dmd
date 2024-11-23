/* TEST_OUTPUT:
---
fail_compilation/aliasassign2.d(28): Error: `alias aa1 = aa1;` cannot alias itself, use a qualified name to create an overload set
    alias aa1 = aa1;
    ^
fail_compilation/aliasassign2.d(31): Error: template instance `aliasassign2.Tp1!()` error instantiating
alias a1 = Tp1!();
           ^
fail_compilation/aliasassign2.d(36): Error: undefined identifier `unknown`
    aa2 = AliasSeq!(aa2, unknown);
          ^
fail_compilation/aliasassign2.d(38): Error: template instance `aliasassign2.Tp2!()` error instantiating
alias a2 = Tp2!();
           ^
fail_compilation/aliasassign2.d(43): Error: template instance `AliasSeqX!(aa3, 1)` template `AliasSeqX` is not defined, did you mean AliasSeq(T...)?
    aa3 = AliasSeqX!(aa3, 1);
          ^
fail_compilation/aliasassign2.d(45): Error: template instance `aliasassign2.Tp3!()` error instantiating
alias a3 = Tp3!();
           ^
---
*/

alias AliasSeq(T...) = T;

template Tp1()
{
    alias aa1 = aa1;
    aa1 = AliasSeq!(aa1, float);
}
alias a1 = Tp1!();

template Tp2()
{
    alias aa2 = AliasSeq!();
    aa2 = AliasSeq!(aa2, unknown);
}
alias a2 = Tp2!();

template Tp3()
{
    alias aa3 = AliasSeq!();
    aa3 = AliasSeqX!(aa3, 1);
}
alias a3 = Tp3!();
