/*
TEST_OUTPUT:
---
fail_compilation/ice9284.d(15): Error: template ice9284.C.__ctor does not match any function template declaration. Candidates are:
fail_compilation/ice9284.d(13):        ice9284.C.__ctor()(string)
fail_compilation/ice9284.d(15): Error: template ice9284.C.__ctor()(string) cannot deduce template function from argument types !()(int)
fail_compilation/ice9284.d(21): Error: template instance ice9284.C.__ctor!() error instantiating
---
*/

class C
{
    this()(string)
    {
        this(10);
        // delegating to a constructor which not exists.
    }
}
void main()
{
    new C("hello");
}
