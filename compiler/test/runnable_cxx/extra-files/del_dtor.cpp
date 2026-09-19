#include "del_dtor.h"
#include <cstdlib>
#include <new>

int newCount = 0;
int deleteCount = 0;

void *operator new(std::size_t size)
{
    newCount++;
    void *p = std::malloc(size ? size : 1);
    if (!p)
        throw std::bad_alloc();
    return p;
}

void operator delete(void *p) noexcept
{
    if (p)
        deleteCount++;
    std::free(p);
}
void operator delete(void *p, std::size_t) noexcept
{
    if (p)
        deleteCount++;
    std::free(p);
}

void deleteDBaseFromCPP(DBase *inst)
{
    delete inst;
}

CppBase::~CppBase()
{
    logDestructorCall("CppBase", i);
}
void deleteCppBaseFromCPP(CppBase *inst)
{
    delete inst;
}
CppBase *createCppBaseFromCPP(int i)
{
    CppBase *inst = new CppBase;
    inst->i = i;
    return inst;
}

void deleteStruct1FromCPP(Struct1 *inst)
{
    delete inst;
}

CppBase2::~CppBase2()
{
    logDestructorCall("CppBase2", i);
}
void deleteCppBase2FromCPP(CppBase2 *inst)
{
    delete inst;
}
