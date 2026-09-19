
void logDestructorCall(const char *name, int value);

class DBase
{
public:
    int i;
    virtual ~DBase();
};
void deleteDBaseFromCPP(DBase *inst);

class CppBase
{
public:
    int i;
    virtual ~CppBase();
};
void deleteCppBaseFromCPP(CppBase *inst);
CppBase *createCppBaseFromCPP(int i);

struct Struct1
{
    int i;
    ~Struct1();
};
void deleteStruct1FromCPP(Struct1 *inst);

class CppBase2
{
public:
    int i;
    virtual ~CppBase2();
};
void deleteCppBase2FromCPP(CppBase2 *inst);
