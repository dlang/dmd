class Outer {
    class Inner {
    }
}
Outer outer;

void main() {
    (outer).new Inner();
}
