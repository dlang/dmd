/+ TEST_OUTPUT:
---
fail_compilation/fail21243.d(26): Error: found `(` when expecting `ref` and function literal following `auto`
auto a = auto (int x) => x;
              ^
fail_compilation/fail21243.d(26): Error: semicolon expected following auto declaration, not `int`
auto a = auto (int x) => x;
               ^
fail_compilation/fail21243.d(26): Error: semicolon needed to end declaration of `x` instead of `)`
auto a = auto (int x) => x;
                    ^
fail_compilation/fail21243.d(26): Error: declaration expected, not `)`
auto a = auto (int x) => x;
                    ^
fail_compilation/fail21243.d(27): Error: `auto` can only be used as part of `auto ref` for function literal return values
auto b = function auto (int x) { return x; };
                       ^
fail_compilation/fail21243.d(28): Error: `auto` can only be used as part of `auto ref` for function literal return values
alias c = auto (int x) => x;
               ^
fail_compilation/fail21243.d(29): Error: `auto` can only be used as part of `auto ref` for function literal return values
alias d = function auto (int x) { return x; };
                        ^
---
+/
auto a = auto (int x) => x;
auto b = function auto (int x) { return x; };
alias c = auto (int x) => x;
alias d = function auto (int x) { return x; };
