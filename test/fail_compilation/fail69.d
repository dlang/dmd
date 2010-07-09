
class C
{
    static const int x;

    void foo()
    {
	x = 4;
    }

    static this()
    {
	x = 5;
    }
}
