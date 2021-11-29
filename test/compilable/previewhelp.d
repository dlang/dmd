/*
ARG_SETS: -preview=?
ARG_SETS: -preview=h
TEST_OUTPUT:
----
Upcoming language changes listed by -preview=name:
  =all              Enables all available upcoming language changes
  =dip25            implement https://github.com/dlang/DIPs/blob/master/DIPs/archive/DIP25.md (Sealed references)
  =dip1000          implement https://github.com/dlang/DIPs/blob/master/DIPs/other/DIP1000.md (Scoped Pointers)
  =dip1008          implement https://github.com/dlang/DIPs/blob/master/DIPs/other/DIP1008.md (@nogc Throwable)
  =dip1021          implement https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1021.md (Mutable function arguments)
  =fieldwise        use fieldwise comparisons for struct equality
  =fixAliasThis     when a symbol is resolved, check alias this scope before going to upper scopes
  =rvaluerefparam   enable rvalue arguments to ref parameters
  =nosharedaccess   disable access to shared memory objects
  =in               `in` on parameters means `scope const [ref]` and accepts rvalues
  =inclusiveincontracts 'in' contracts of overridden methods must be a superset of parent contract
  =shortenedMethods allow use of => for methods and top-level functions in addition to lambdas
----
*/
