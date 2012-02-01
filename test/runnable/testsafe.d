// PERMUTE_ARGS: 
 
//http://d.puremagic.com/issues/show_bug.cgi?id=5415 
 
@safe 
void pointercast() 
{ 
    int* a; 
    void* b; 
 
    static assert( __traits(compiles, cast(void*)a)); 
    static assert(!__traits(compiles, cast(int*)b)); 
    static assert(!__traits(compiles, cast(int*)b)); 
    static assert(!__traits(compiles, cast(short*)b)); 
    static assert( __traits(compiles, cast(byte*)b)); 
    static assert( __traits(compiles, cast(short*)a)); 
    static assert( __traits(compiles, cast(byte*)a)); 
} 
 
@safe 
void pointercast2() 
{ 
    size_t a; 
    int b; 
    Object c; 
 
    static assert(!__traits(compiles, cast(void*)a)); 
    static assert(!__traits(compiles, cast(void*)b)); 
    static assert(!__traits(compiles, cast(void*)c)); 
} 
 
@safe 
void pointerarithmetic() 
{//http://d.puremagic.com/issues/show_bug.cgi?id=4132 
    void* a; 
    int b; 
 
    static assert(!__traits(compiles, a + b)); 
    static assert(!__traits(compiles, a - b)); 
    static assert(!__traits(compiles, a += b)); 
    static assert(!__traits(compiles, a -= b)); 
    static assert(!__traits(compiles, a++)); 
    static assert(!__traits(compiles, a--)); 
    static assert(!__traits(compiles, ++a)); 
    static assert(!__traits(compiles, --a)); 
} 
 
 
 
union SafeUnion1 
{ 
    int a; 
    struct 
    { 
        int b; 
        int* c; 
    } 
} 
union SafeUnion2 
{ 
    int a; 
    struct 
    { 
        int b; 
        int c; 
    } 
} 
union UnsafeUnion1 
{ 
    int a; 
    int* c; 
} 
union UnsafeUnion2 
{ 
    int a; 
    align(1) 
    struct 
    { 
        byte b; 
        int* c; 
    } 
} 
union UnsafeUnion3 
{ 
    int a; 
    Object c; 
} 
union UnsafeUnion4 
{ 
    int a; 
    align(1) 
    struct 
    { 
        byte b; 
        Object c; 
    } 
} 
struct pwrapper 
{ 
    int* a; 
} 
union UnsafeUnion5 
{ 
    SafeUnion2 x; 
    pwrapper b; 
} 
 
SafeUnion1 su1; 
SafeUnion2 su2; 
UnsafeUnion1 uu1; 
UnsafeUnion2 uu2; 
UnsafeUnion3 uu3; 
UnsafeUnion4 uu4; 
UnsafeUnion5 uu5; 
 
union uA 
{ 
    struct 
    { 
        int* a; 
        void* b; 
    } 
} 
struct uB 
{ 
    uA a; 
} 
struct uC 
{ 
    uB a; 
} 
struct uD 
{ 
    uC a; 
} 
uD uud; 
 
@safe 
void safeunions() 
{ 
    //static assert( __traits(compiles, { SafeUnion1 x; x.a = 7; })); 
    static assert( __traits(compiles, { SafeUnion2 x; x.a = 7; })); 
    static assert(!__traits(compiles, { UnsafeUnion1 x; x.a = 7; })); 
    static assert(!__traits(compiles, { UnsafeUnion2 x; x.a = 7; })); 
    static assert(!__traits(compiles, { UnsafeUnion3 x; x.a = 7; })); 
    static assert(!__traits(compiles, { UnsafeUnion4 x; x.a = 7; })); 
    static assert(!__traits(compiles, { UnsafeUnion5 x; })); 
 
    typeof(uu1.a) f; 
 
    //static assert( __traits(compiles, { su1.a = 7; })); 
    static assert( __traits(compiles, { su2.a = 7; })); 
    static assert(!__traits(compiles, { uu1.a = 7; })); 
    static assert(!__traits(compiles, { uu2.a = 7; })); 
    static assert(!__traits(compiles, { uu3.a = 7; })); 
    static assert(!__traits(compiles, { uu4.a = 7; })); 
    static assert(!__traits(compiles, { uu5.x.a = null; })); 
    static assert(!__traits(compiles, { uud.a.a.a.a = null; })); 
} 
 
 
 
void systemfunc() @system {} 
void function() @system sysfuncptr; 
void delegate() @system sysdelegate; 
 
@safe 
void callingsystem() 
{ 
    static assert(!__traits(compiles, systemfunc())); 
    static assert(!__traits(compiles, sysfuncptr())); 
    static assert(!__traits(compiles, sysdelegate())); 
} 
 
@safe 
void safeexception() 
{ 
    try {} 
    catch(Exception e) {} 
 
    static assert(!__traits(compiles, { 
        try {} 
        catch(Error e) {} 
    })); 
 
    static assert(!__traits(compiles, { 
        try {} 
        catch(Throwable e) {} 
    })); 
 
    static assert(!__traits(compiles, { 
        try {} 
        catch {} 
    })); 
} 
 
@safe 
void inlineasm() 
{ 
    static assert(!__traits(compiles, { asm { int 3; } }() )); 
} 
 
@safe 
void multablecast() 
{ 
    Object m; 
    const(Object) c; 
    immutable(Object) i; 
 
    static assert( __traits(compiles, cast(const(Object))m)); 
    static assert( __traits(compiles, cast(const(Object))i)); 
 
    static assert(!__traits(compiles, cast(immutable(Object))m)); 
    static assert(!__traits(compiles, cast(immutable(Object))c)); 
 
    static assert(!__traits(compiles, cast(Object)c)); 
    static assert(!__traits(compiles, cast(Object)i)); 
 
    void* mp; 
    const(void)* cp; 
    immutable(void)* ip; 
 
    static assert( __traits(compiles, cast(const(void)*)mp)); 
    static assert( __traits(compiles, cast(const(void)*)ip)); 
 
    static assert(!__traits(compiles, cast(immutable(void)*)mp)); 
    static assert(!__traits(compiles, cast(immutable(void)*)cp)); 
 
    static assert(!__traits(compiles, cast(void*)cp)); 
    static assert(!__traits(compiles, cast(void*)ip)); 
} 
 
@safe 
void sharedcast() 
{ 
    Object local; 
    shared(Object) xshared; 
    immutable(Object) ishared; 
 
    static assert(!__traits(compiles, cast()xshared)); 
    static assert(!__traits(compiles, cast(shared)local)); 
 
    static assert(!__traits(compiles, cast(immutable)xshared)); 
    static assert(!__traits(compiles, cast(shared)ishared)); 
} 
 
int threadlocalvar; 
 
@safe 
void takeaddr() 
{ 
    static assert(!__traits(compiles, (int x) { auto y = &x; } )); 
    static assert(!__traits(compiles, { int x; auto y = &x; } )); 
    static assert( __traits(compiles, { static int x; auto y = &x; } )); 
    static assert( __traits(compiles, { auto y = &threadlocalvar; } )); 
} 
 
__gshared int gsharedvar; 
 
@safe 
void use__gshared() 
{ 
    static assert(!__traits(compiles, { int x = gsharedvar; } )); 
} 
 
@safe 
void voidinitializers() 
{//http://d.puremagic.com/issues/show_bug.cgi?id=4885 
    static assert(!__traits(compiles, { uint* ptr = void; } )); 
    static assert( __traits(compiles, { uint i = void; } )); 
    static assert( __traits(compiles, { uint[2] a = void; } )); 
 
    struct ValueStruct { int a; } 
    struct NonValueStruct { int* a; } 
    static assert( __traits(compiles, { ValueStruct a = void; } )); 
    static assert(!__traits(compiles, { NonValueStruct a = void; } )); 
 
    static assert(!__traits(compiles, { uint[] a = void; } )); 
    static assert(!__traits(compiles, { int** a = void; } )); 
    static assert(!__traits(compiles, { int[int] a = void; } )); 
} 
 
@safe 
void basiccast() 
{//http://d.puremagic.com/issues/show_bug.cgi?id=5088 
    auto a = cast(int)cast(const int)1; 
    auto b = cast(real)cast(const int)1; 
    auto c = cast(real)cast(const real)2.0; 
} 
 
@safe 
void arraycast() 
{ 
    int[] x; 
    void[] y = x; 
    static assert( __traits(compiles, cast(void[])x)); 
    static assert( __traits(compiles, cast(int[])y)); 
    static assert(!__traits(compiles, cast(int*[])y)); 
    static assert(!__traits(compiles, cast(void[][])y)); 
 
    int[3] a; 
    int[] b = cast(int[])a; 
    uint[3] c = cast(uint[3])a; 
} 
 
@safe 
void structcast() 
{ 
    struct A { ptrdiff_t x; } 
    struct B { size_t x; } 
    struct C { void* x; } 
    A a; 
    B b; 
    C c; 
 
    static assert( __traits(compiles, a = cast(A)b)); 
    static assert( __traits(compiles, a = cast(A)c)); 
    static assert( __traits(compiles, b = cast(B)a)); 
    static assert( __traits(compiles, b = cast(B)c)); 
    static assert(!__traits(compiles, c = cast(C)a)); 
    static assert(!__traits(compiles, c = cast(C)b)); 
} 

@safe
void varargs()
{
    static void fun(string[] val...) {}
    fun("a");
}

extern(C++) interface E {}
extern(C++) interface F : E {}

@safe
void classcast()
{
    class A {};
    class B : A {};

    A a;
    B b;

    static assert( __traits(compiles, cast(A)a));
    static assert( __traits(compiles, cast(B)a));
    static assert( __traits(compiles, cast(A)b));
    static assert( __traits(compiles, cast(B)b));

    interface C {};
    interface D : C {};

    C c;
    D d;

    static assert( __traits(compiles, cast(C)c));
    static assert( __traits(compiles, cast(D)c));
    static assert( __traits(compiles, cast(C)d));
    static assert( __traits(compiles, cast(D)d));

    E e;
    F f;

    static assert( __traits(compiles, cast(E)e));
    static assert(!__traits(compiles, cast(F)e));
    static assert( __traits(compiles, cast(E)f));
    static assert( __traits(compiles, cast(F)f));
}

@safe
{

class A6278 {
    int test()
    in { assert(0); }
    body { return 1; }
}
class B6278 : A6278 {
    override int test()
    in { assert(0); }
    body { return 1; }
}

}

void main() { } 

