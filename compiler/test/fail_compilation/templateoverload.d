/*
TEST_OUTPUT:
---
fail_compilation/templateoverload.d(29): Error: template instance `T!1` does not match any template declaration
alias t = T!1;
          ^
fail_compilation/templateoverload.d(29):        Candidates are:
fail_compilation/templateoverload.d(26):        T(X)
template T(X) {}
^
fail_compilation/templateoverload.d(27):        T()
template T() {}
^
fail_compilation/templateoverload.d(34): Error: template instance `V!int` does not match any template declaration
alias v = V!int;
          ^
fail_compilation/templateoverload.d(34):        Candidates are:
fail_compilation/templateoverload.d(31):        V(int i)
template V(int i) {}
^
fail_compilation/templateoverload.d(32):        V(T, alias a)
template V(T, alias a) {}
^
---
*/
template T(X) {}
template T() {}

alias t = T!1;

template V(int i) {}
template V(T, alias a) {}

alias v = V!int;
