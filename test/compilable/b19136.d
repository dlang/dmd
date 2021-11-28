// REQUIRED_ARGS: -c

/* --------------------------------------- */
static assert(!is(int T == void));
static assert(!is(int T == bool));
static assert(!is(int T == byte));
static assert(!is(int T == ubyte));
static assert(!is(int T == short));
static assert(!is(int T == ushort));
// static assert(!is(int T == int));
static assert(!is(int T == uint));
static assert(!is(int T == long));
static assert(!is(int T == ulong));
static assert(!is(int T == cent));
static assert(!is(int T == ucent));
static assert(!is(int T == float));
static assert(!is(int T == double));
static assert(!is(int T == real));
static assert(!is(int T == ifloat));
static assert(!is(int T == idouble));
static assert(!is(int T == ireal));
static assert(!is(int T == cfloat));
static assert(!is(int T == cdouble));
static assert(!is(int T == creal));
static assert(!is(int T == char));
static assert(!is(int T == wchar));
static assert(!is(int T == dchar));

/* --------------------------------------- */
static assert(!is(int T : void));
static assert(!is(int T : bool));
static assert(!is(int T : byte));
static assert(!is(int T : ubyte));
static assert(!is(int T : short));
static assert(!is(int T : ushort));
// static assert(!is(int T : int));
static assert(!is(int T : uint));
static assert(!is(int T : long));
static assert(!is(int T : ulong));
static assert(!is(int T : cent));
static assert(!is(int T : ucent));
static assert(!is(int T : float));
static assert(!is(int T : double));
static assert(!is(int T : real));
static assert(!is(int T : ifloat));
static assert(!is(int T : idouble));
static assert(!is(int T : ireal));
static assert(!is(int T : cfloat));
static assert(!is(int T : cdouble));
static assert(!is(int T : creal));
static assert(!is(int T : char));
static assert(!is(int T : wchar));
static assert(!is(int T : dchar));
