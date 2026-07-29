// Test that immutable arguments to pure functions allow result to be treated as immutable.
// Issue: When determining uniqueness of results, the language takes uniqueness of arguments
// into account, but not immutable.

const(int)[] f(const(int)[] xs) @safe pure;

void main() @safe
{
    immutable(int)[] arr;
    immutable int[] ys = f([0]); // good - argument is unique
    immutable int[] zs = f(arr); // should also work - argument is immutable
}
