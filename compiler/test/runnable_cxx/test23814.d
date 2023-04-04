// EXTRA_CPP_SOURCES: cpp23814.cpp
// CXXFLAGS: -O -m32
// REQUIRED_ARGS: -m32
// DISABLED: win64 linux64 osx64 freebsd64 dragonflybsd64 netbsd64 win32

extern(C++) interface BaseInterface1
{
public:
    int func1();
    int func2();
}

extern(C++) abstract class BaseInterface2
{
public:
    int func3() {return 3;}
    int func4() {return 4;}
}

extern(C++) class MainClass : BaseInterface2, BaseInterface1
{
    override int func1() {return 1;}
    override int func2() {return 2;}
}

extern(C++) int cppFunc1(BaseInterface1 obj);

int main()
{
    BaseInterface1 cls = new MainClass();
    assert(cppFunc1(cls) == 3);
    return 0;
}
