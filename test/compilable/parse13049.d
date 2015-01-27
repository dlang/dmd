enum mangle(T) = T.mangleof;
alias Func = void function(scope int);                              // OK
static assert(mangle!Func == mangle!(void function(scope int)));    // OK <- NG
