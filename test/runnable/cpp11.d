// DISABLED: win32
// REQUIRED_ARGS: -extern-std=c++11
// EXTRA_CPP_SOURCES: cpp11.cpp
// CXXFLAGS: -std=c++11

// Disabled on win32 because the compiler is too old

import core.stdc.stdint;

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

enum i8_19658 : int8_t { a }
enum u8_19658 : uint8_t { a }
enum i16_19658 : int16_t { a }
enum u16_19658 : uint16_t { a }
enum i32_19658 : int32_t { a }
enum u32_19658 : uint32_t { a }
enum i64_19658 : int64_t { a }
enum u64_19658 : uint64_t { a }

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

/****************************************/

void main()
{
    test17();
    test19658();
}
