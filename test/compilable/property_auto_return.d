// PERMUTE_ARGS:

// Checking that @property storage class is applied correctly to function with
// deduced return type. If not applied, will cause an error complaining about
// property and non-prooperty functions beging overloaded.

@property int test() { return 1; }
@property auto test(int i) { return i; }

@property int test2() { return 1; }
@property auto ref test2(int i) { return i; }