/*
TEST_OUTPUT:
---
fail_compilation/ice13835.d(19): Error: value of `this` is not known at compile time
        static T crash = *(this._data + position);
                           ^
fail_compilation/ice13835.d(25): Error: template instance `ice13835.Foo!int` error instantiating
    auto heap = new Foo!(int);
                    ^
---
*/

class Foo(T)
{
    private T* _data;

    final private void siftUp(int position) nothrow
    {
        static T crash = *(this._data + position);
    }
}

void main()
{
    auto heap = new Foo!(int);
}
