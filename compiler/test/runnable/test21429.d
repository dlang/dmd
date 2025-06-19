mixin template OD(string s)
{

    string opDispatch(string name)() if (name == s)
    {
        return name;
    }
}

mixin template ODA(string s)
{
    void opDispatch(string name)(int x) if (name == s)
    {
        this.val = x;
    }
}

struct T
{
    mixin OD!"x";
    mixin OD!"y";
}

struct TAssign
{
    int val;
    mixin ODA!"x";
    mixin ODA!"y";
}

struct U
{
    mixin OD!"z";
}


template adder()
{
    int opBinary(string s : "+")(int x) { return x; }
}

template subtracter()
{
    int opBinary(string s : "-")(int x) { return x; }
}


struct Arithmetic
{
    mixin adder;
    mixin subtracter;

}

void main(){

    T t;
    string s = t.x();
    assert(s == "x");
    assert(t.y == "y");

    //explicit call should work
    assert(t.opDispatch!"x" == "x");


    //TODO: fix these
    Arithmetic a;
    //a + 5; // error a.opBinary isn't a template (is an overload set, I assume)
    //a - 5; // error

    //t.opDispatch!"y";

    U u;
    //should work for a single mixin
    assert(u.z == "z");

    TAssign ta;
    ta.x = 5;
    assert(ta.val == 5);
    ta.y = 10;
    assert(ta.val == 10);
}
