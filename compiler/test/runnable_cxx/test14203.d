// EXTRA_CPP_SOURCES: c14203.cpp
// CXXFLAGS(osx): -arch x86_64


/************************************************/

// https://issues.dlang.org/show_bug.cgi?id=14203

extern (C++) float func1();

void test14203()
{
    assert(func1() == 73);
}

/************************************************/

int main()
{
    test14203();

    return 0;
}
