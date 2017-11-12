// The purpose of this test is to ensure that the implementation of
// DIP1015 does not break the following conditionals

void main()
{
    if(1) { }
    if(0) { }
    assert(1);
    assert(0);
    static assert(1);
    while(0) { }
    while(1) { }
    for(;1;) { }
}
