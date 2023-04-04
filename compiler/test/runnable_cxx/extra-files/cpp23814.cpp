class BaseInterface1
{
public:
    virtual int func1();
    virtual int func2();
};

class BaseInterface2
{
public:
    virtual int func3();
    virtual int func4();
};

class MainClass : BaseInterface2, BaseInterface1
{
    virtual int func1();
    virtual int func2();
};

int cppFunc1(BaseInterface1* obj)
{
    int a = obj->func1();
    int b = obj->func2();
    return a + b;
}
