// REQUIRED_ARGS: -c -o-

static if(is(typeof(X13!(0).init))) {}
template X13(Y13 y) {}
