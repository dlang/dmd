// DISABLED: win32
// REQUIRED_ARGS: -extern-std=c++11
// EXTRA_CPP_SOURCES: cpp11.cpp
// CXXFLAGS(osx linux freebsd openbsd netbsd dragonflybsd solaris): -std=c++11

// Disabled on win32 because the compiler is too old

/****************************************/
alias nullptr_t = typeof(null);

// Only run on OSX/Win64 because the compilers are too old
// and nullptr_t gets substituted
version (FreeBSD)
    version = IgnoreNullptrTest;
version (linux)
    version = IgnoreNullptrTest;

version (IgnoreNullptrTest) { void test17() {} }
else
{
    extern (C++) void testnull(nullptr_t);
    extern (C++) void testnullnull(nullptr_t, nullptr_t);

    void test17()
    {
        testnull(null);
        testnullnull(null, null);
    }
}

/****************************************/
// https://issues.dlang.org/show_bug.cgi?id=19658

enum i8_19658 : byte { a }
enum u8_19658 : ubyte { a }
enum i16_19658 : short { a }
enum u16_19658 : ushort { a }
enum i32_19658 : int { a }
enum u32_19658 : uint { a }
enum i64_19658 : long { a }
enum u64_19658 : ulong { a }

extern(C++) void test19658_i8(i8_19658);
extern(C++) void test19658_u8(u8_19658);
extern(C++) void test19658_i16(i16_19658);
extern(C++) void test19658_u16(u16_19658);
extern(C++) void test19658_i32(i32_19658);
extern(C++) void test19658_u32(u32_19658);
extern(C++) void test19658_i64(i64_19658);
extern(C++) void test19658_u64(u64_19658);

void test19658()
{
    test19658_i8(i8_19658.a);
    test19658_u8(u8_19658.a);
    test19658_i16(i16_19658.a);
    test19658_u16(u16_19658.a);
    test19658_i32(i32_19658.a);
    test19658_u32(u32_19658.a);
    test19658_i64(i64_19658.a);
    test19658_u64(u64_19658.a);
}

version(OSX)
{
    void test15523(){}
}
else
{
    /****************************************/
    extern(C++)
    {
        int i15523_d;
        extern int i15523_cpp;
        
        void test15523d(int a)
        {
            assert(i15523_cpp == a + 1);
            assert(i15523_d   == a + 2);
        }

        void test15523cpp(int);

        struct S
        {
            this(int f);
            int field;
        }
        S tls;
        void fromCxx();
    }

    void test15523()
    {
        i15523_d = 42;
        i15523_cpp = 42;
        test15523cpp(42);
        test15523d(42);
        
        tls = S(0xdeadbeef);
        fromCxx();
    }
}
void main()
{
    test17();
    test15523();
    test19658();
}
