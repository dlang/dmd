// https://github.com/dlang/dmd/issues/23270
// NaN and infinity should print as valid D expressions
static assert(float.nan.stringof == "float.nan");
static assert(double.nan.stringof == "double.nan");
static assert(real.nan.stringof == "real.nan");
static assert(float.infinity.stringof == "float.infinity");
static assert(double.infinity.stringof == "double.infinity");
static assert(real.infinity.stringof == "real.infinity");
static assert((-float.infinity).stringof == "-float.infinity");
static assert((-double.infinity).stringof == "-double.infinity");
