// https://github.com/dlang/dmd/issues/23392
struct Parser { @disable this(); this(int) {} }
class Client { Parser parser; this() { parser = Parser(0); } }
void sink(out Client r) {}
void main() {
    Client c;
    // passing c just sets it to null, so no @disable error needed
    sink(c);
}
