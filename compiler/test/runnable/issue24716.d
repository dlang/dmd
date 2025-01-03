// https://issues.dlang.org/show_bug.cgi?id=24716
int i = 1;
void foo(int arg)
{
    assert( arg == 100*i);
    i++;
}
class Outer1 {
    int value1 = 100;

    class Inner1 {
        void print() {
            foo(value1);
        }
    }

    Inner1 make() { return new Inner1; }
}

class Outer2 : Outer1 {
    int value2 = 200;

    class Inner2 : Outer1.Inner1 {
        override void print() {
            foo(value1); // <- no problem!
            foo(value2); // error: accessing non-static variable `value2` requires an instance of `Outer2`
        }
    }

    override Inner2 make() { return new Inner2; }
}

void main()
{
    auto oouter = new Outer2;
    auto iinner = oouter.make();
    iinner.print();
}
