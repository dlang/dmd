/*
TEST_OUTPUT:
---
fail_compilation/fail15167.d(12): Error: alias fail15167.Ulong15167 conflicts with alias fail15167.Ulong15167 at fail_compilation/fail15167.d(11)
fail_compilation/fail15167.d(16): Error: alias fail15167.Array15167 conflicts with alias fail15167.Array15167 at fail_compilation/fail15167.d(15)
fail_compilation/fail15167.d(20): Error: alias fail15167.StructType15167 conflicts with alias fail15167.StructType15167 at fail_compilation/fail15167.d(19)
fail_compilation/fail15167.d(24): Error: alias fail15167.ClassType15167 conflicts with alias fail15167.ClassType15167 at fail_compilation/fail15167.d(23)
---
*/

alias Ulong15167 = ulong;
alias Ulong15167 = const ulong;             // error

alias UlongAlias15167 = ulong;
alias Array15167 = UlongAlias15167[]*;
alias Array15167 = UlongAlias15167[];       // error

struct S15167 {}
alias StructType15167 = S15167;
alias StructType15167 = S15167[];           // error

class C15167 {}
alias ClassType15167 = C15167[1];
alias ClassType15167 = C15167;              // error
