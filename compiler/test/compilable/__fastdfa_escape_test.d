// DO NOT RENAME THIS MODULE, name enables __FastDFAEscapeTest UDA

/*
REQUIRED_ARGS: -preview=fastdfa
*/
module __fastdfa_escape_test;

struct __FastDFAEscapeTest {
    Param[] params;
}

struct Param {
    bool escapeIntoNothing;
    ulong escapeInto;

    this(bool escapeIntoNothing, ulong escapeInto) {
        this.escapeIntoNothing = escapeIntoNothing;
        this.escapeInto = escapeInto;
    }
}

struct Base {
    int* field;
}

struct S1
{
    S2 s2;
}

struct S2
{
    int field;
}

struct S3
{
    S2* s2;
}

enum Nothing = __FastDFAEscapeTest(null);
enum EscapeToGlobalPtr = __FastDFAEscapeTest([Param(false, 32)]);
enum NoWhere001 = __FastDFAEscapeTest([Param(true, 0)]);
enum Returns001 = __FastDFAEscapeTest([Param(false, 1)]);
enum Returns001Ptr = __FastDFAEscapeTest([Param(false, 2)]);

#line 1000

//
//
//

@NoWhere001
void goesNoWhere1(int* ptr) {
}

@NoWhere001
void goesNoWhere2(scope int* ptr) {
}

@NoWhere001
void goesNoWhere3(int* ptr) {
    int* ptr2 = ptr;
}

@NoWhere001
void goesNoWhere4(scope int* ptr) {
    int* ptr2 = ptr;
}

@NoWhere001
void goesNoWhere5(int* ptr) {
    int* ptr2 = ptr;
    int var = *ptr2;
}

@NoWhere001
void goesNoWhere6(scope int* ptr) {
    int* ptr2 = ptr;
    int var = *ptr2;
}

@Returns001Ptr
int* returnArg1(int* ptr) {
    return ptr;
}

@Returns001
int* returnArg2(ref int* ptr) {
    return ptr;
}

@Returns001Ptr
ref int returnArgRef1(ref int ptr) {
    return ptr;
}

@Returns001Ptr
ref int* returnArgRef2(ref int* ptr) {
    return ptr;
}

@Returns001Ptr
int** returnArgRef3(ref int* ptr) {
    return &ptr;
}

@Returns001Ptr
ref S2 returnArgRef4(ref const(S2) x)
{
    return cast() x; // ok
}

@Returns001
int* returnArgField(Base* base) {
    return base.field;
}

@Returns001Ptr
int** returnArgPtr(Base* base) {
    return &base.field;
}

@Nothing
void trackEscape1()
{
    S1 s1;
    int* ptr = &s1.s2.field; // ok
    S2* s2 = &s1.s2; // ok
}

@Returns001Ptr
S2* trackEscape2(S1* s1)
{
    int* ptr = &s1.s2.field; // ok
    return &s1.s2; // ok
}

@Nothing
void trackEscape5()
{
    int* ptr;

    {
        int var;
        ptr = &var;
    } // no error
} // no error

@Nothing
int* trackEscape7()
{
    S3 var;
    return &var.s2.field; // ok
}

@NoWhere001
void trackEscape10(int* ptr)
{
    int buf;
    ptr = &buf; // ok
}

@EscapeToGlobalPtr
void escapeToGlobalSystem2(scope int* ptr1) @system
{
    __gshared int* ptr2;

    ptr2 = ptr1; // ok
}

@Returns001Ptr
int* returnArrayElement(int[] data)
{
    foreach (ref datem; data)
    {
        return &datem; // ok
    }

    return null;
}

//
//
//

@Returns001Ptr
int* callReturn(int* input) {
    return returnArg1(input);
}

@Returns001
int* callReturnArg2(ref int* ptr) {
    return returnArg2(ptr);
}

@Returns001Ptr
int** callReturnArgRef3(ref int* ptr) {
    return returnArgRef3(ptr);
}

@Returns001Ptr
int** callReturnArgPtr(Base* base) {
    return returnArgPtr(base);
}

@Returns001
int* argValue(scope Base* base) {
    return base.field;
}

@Nothing
S2** pointerToObjectField()
{
    S3* s = new S3;
    return &s.s2;
} // ok
