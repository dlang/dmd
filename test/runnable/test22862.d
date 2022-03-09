module test22862;

int fun() { return 1; }
string fun() { return "hello"; }

void main() {
    // fun can only be called by selecting a specific overload
    static assert(!__traits(compiles, fun()));
    assert(__traits(getOverloads, test22862, "fun")[0]() == 1);
    assert(__traits(getOverloads, test22862, "fun")[1]() == "hello");
}
