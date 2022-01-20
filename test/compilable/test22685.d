module test22685;

import imports.test22685b;

void twoArgs(alias a, alias b)() { }

void main() {
    twoArgs!(a => 1, overloaded);
}
