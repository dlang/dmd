class Base
{
public:
    int i;
    Base();
    virtual int f();
};

class Interface
{
public:
    virtual int g() = 0;
};

class C : public Base, public Interface
{
public:
    C();
    int g();
};

class Interface2
{
public:
    virtual int g2() = 0;
    virtual int g3() = 0;
};

class Interface3
{
public:
    virtual int g4() = 0;
    virtual int g5() = 0;
};

class E : public C, public Interface2, public Interface3
{
public:
    E();
    int g2();
    int g3();
    int g4();
    int g5();
};
