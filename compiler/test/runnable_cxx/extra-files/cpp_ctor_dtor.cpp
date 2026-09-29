#include <new>

extern "C" void trace_log(char c);

class A2 { public: virtual ~A2(); };
class A3 { public: virtual ~A3(); };
class A5 { public: virtual ~A5(); };

void cpp_destroy_a2(A2* p) { p->~A2(); }
void cpp_destroy_a3(A3* p) { p->~A3(); }
void cpp_destroy_a5(A5* p) { p->~A5(); }

class CppBase
{
public:
    virtual ~CppBase();
    virtual int id();
};

CppBase::~CppBase() { trace_log('P'); }
int CppBase::id() { return 0; }

void cpp_destroy_cppbase(CppBase* p) { p->~CppBase(); }

class CppAbstract
{
public:
    CppAbstract();
    virtual ~CppAbstract();
    virtual int id() = 0;
};

CppAbstract::CppAbstract() { trace_log('K'); }
CppAbstract::~CppAbstract() { trace_log('Q'); }

void cpp_destroy_abstract(CppAbstract* p) { p->~CppAbstract(); }

class DBase
{
public:
    DBase();
    virtual ~DBase();
    virtual int id();
};

class CppFromD : public DBase
{
public:
    CppFromD() { trace_log('C'); }
    ~CppFromD() { trace_log('E'); }
    int id() { return 2; }
};

static char storage[sizeof(CppFromD)];

DBase* make_cpp_from_d() { return new (storage) CppFromD(); }
void cpp_destroy_dbase(DBase* p) { p->~DBase(); }
