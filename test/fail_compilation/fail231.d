 // bug951   -- File but no line number. func.c
/*
bug.d: constructor bug.Derived.this no match for implicit super() call in const
*/
class Base {
    this(int x) {}
}

class Derived : Base {}
