/*
ARG_SETS: -preview=?
ARG_SETS: -preview=h
TEST_OUTPUT:
----
Upcoming language changes listed by -preview=name:
  =all              Enables all available upcoming language changes
  =dip25            implement Sealed References DIP [DEPRECATED] (https://github.com/dlang/DIPs/blob/master/DIPs/archive/DIP25.md)
  =dip1000          implement Scoped Pointers DIP (https://github.com/dlang/DIPs/blob/master/DIPs/other/DIP1000.md)
  =dip1008          implement @nogc Throwable DIP (https://github.com/dlang/DIPs/blob/master/DIPs/other/DIP1008.md)
  =dip1021          implement Mutable Function Arguments DIP (https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1021.md)
  =bitfields        add C-like bitfields (https://github.com/dlang/dlang.org/pull/3190)
  =fieldwise        use fieldwise comparisons for struct equality (https://dlang.org/changelog/2.085.0.html#no-cmpsb)
  =fixAliasThis     when a symbol is resolved, check alias this scope before going to upper scopes (https://github.com/dlang/dmd/pull/8885)
  =rvaluerefparam   enable rvalue arguments to ref parameters (https://gist.github.com/andralex/e5405a5d773f07f73196c05f8339435a)
  =nosharedaccess   disable access to shared memory objects (https://dlang.org/spec/const3.html#shared)
  =in               `in` on parameters means `scope const [ref]` and accepts rvalues (https://dlang.org/spec/function.html#in-params)
  =inclusiveincontracts 'in' contracts of overridden methods must be a superset of parent contract (https://dlang.org/changelog/2.095.0.html#inclusive-incontracts)
  =fixImmutableConv disallow functions with a mutable `void[]` parameter to be strongly pure (https://dlang.org/changelog/2.101.0.html#dmd.fix-immutable-conv)
  =systemVariables  disable access to variables marked '@system' from @safe code (https://dlang.org/spec/attribute.html#system-variables)
----
*/
