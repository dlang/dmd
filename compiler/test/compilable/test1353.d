
class A {}
interface B {}
interface C {}
interface D(X) {}

void fun()
{
    class T : typeof(new A), .B, C, D!int {}
    version(none)
    {
        class U : int, float {}
    }
}
