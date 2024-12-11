/* REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/commaexp.d(47): Error: using the result of a comma expression is not allowed
    enum ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED = (WINHTTP_ERROR_BASE, + 44);
                                                  ^
fail_compilation/commaexp.d(59): Error: using the result of a comma expression is not allowed
    for (size_t i; i < 5; ++i, i += (i++, 1)) {}
                                     ^
fail_compilation/commaexp.d(60): Error: using the result of a comma expression is not allowed
    for (; aggr++, aggr > 5;) {}
           ^
fail_compilation/commaexp.d(61): Error: using the result of a comma expression is not allowed
    if (Object o = (ok = true, null)) {}
    ^
fail_compilation/commaexp.d(62): Error: using the result of a comma expression is not allowed
    ok = (true, mc.append(new Entry));
       ^
fail_compilation/commaexp.d(64): Error: using the result of a comma expression is not allowed
    ok = true, (ok = (true, false));
                   ^
fail_compilation/commaexp.d(65): Error: using the result of a comma expression is not allowed
    return 42, 0;
           ^
fail_compilation/commaexp.d(76): Error: using the result of a comma expression is not allowed
    return type == Type.Colon, type == Type.Comma;
           ^
fail_compilation/commaexp.d(89): Error: using the result of a comma expression is not allowed
    return type == Type.Colon, type == Type.Comma;
           ^
fail_compilation/commaexp.d(101): Error: using the result of a comma expression is not allowed
    bar11((i,p), &i);
           ^
---
*/

class Entry {}
class MyContainerClass { bool append (Entry) { return false; } }

int main () {
    bool ok;
    size_t aggr;
    MyContainerClass mc;

    // https://issues.dlang.org/show_bug.cgi?id=15997
    enum WINHTTP_ERROR_BASE = 4200;
    enum ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED = (WINHTTP_ERROR_BASE, + 44);

    // OK
    for (size_t i; i < 5; ++i, i += 1) {}
    for (size_t i; i < 5; ++i, i += 1, i++) {}
    if (!mc)
        mc = new MyContainerClass, mc.append(new Entry);
    if (Object o = cast(Object)mc) {} // Lowering
    ok = true, mc.append(new Entry);
    assert(ok);

    // NOPE
    for (size_t i; i < 5; ++i, i += (i++, 1)) {}
    for (; aggr++, aggr > 5;) {}
    if (Object o = (ok = true, null)) {}
    ok = (true, mc.append(new Entry));
    assert(!ok);
    ok = true, (ok = (true, false));
    return 42, 0;
}


/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=16022

bool test16022()
{
    enum Type { Colon, Comma }
    Type type;
    return type == Type.Colon, type == Type.Comma;
}

bool test16022_structs()
{
    struct A
    {
        int i;
        string s;
    }

    enum Type { Colon = A(0, "zero"), Comma = A(1, "one") }
    Type type;
    return type == Type.Colon, type == Type.Comma;
}

/********************************************/


void bar11(int*, int*) { }

void test11()
{
    static int* p;
    static int i;
    bar11((i,p), &i);
}
