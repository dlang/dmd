struct Struct {
    SumType!() v1;
}
void foo()() { SumType!() v2; }
struct SumType() {
    ~this() { }
    invariant { alias a = {}; match!a(); }

}
void match(alias handler)() { }
