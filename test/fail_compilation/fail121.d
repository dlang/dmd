// compile with -d

struct myobject
{
    TypeInfo objecttype; 
    void * offset;
}

myobject[] list;

void foo()
{
    int i;

    list[1].typeinfo=i.typeinfo;
}
