class Base
{
public:
    virtual ~Base();
};

void deleteFromCpp(Base *b)
{
    delete b;
}
