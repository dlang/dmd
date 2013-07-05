// EXTRA_CPP_SOURCES: externmangle.cpp

extern(C++) int test1(); 


void main()
{
    assert(test1());
}
