// PERMUTE_ARGS:

// Prefer void* over all others
void foo(const void* a)     { assert(0); }
void foo(const int* a)      { assert(0); }
void foo(void* a)           { assert("yay!"); }
void foo(int* a)            { assert(0); }
void foo(immutable void* a) { assert(0); }
void foo(immutable int* a)  { assert(0); }
void foo(int[] a)           { assert(0); }
void foo(void[] a)          { assert(0); }
void foo(void delegate() a) { assert(0); }
void foo(int[int] a)        { assert(0); }

// Prefer immutable(char)[] to all others
void bar(char[] a)            { assert(0); }
void bar(const char[] a)      { assert(0); }
void bar(immutable char[] a)  { assert("yay!"); }
void bar(wchar[] a)           { assert(0); }
void bar(const wchar[] a)     { assert(0); }
void bar(immutable wchar[] a) { assert(0); }
void bar(dchar[] a)           { assert(0); }
void bar(const dchar[] a)     { assert(0); }
void bar(immutable dchar[] a) { assert(0); }

// Prefer const conversion over polysemous conversion
void foo2(const void* a)     { assert("yay!"); }
void foo2(const int* a)      { assert(0); }
void foo2(int* a)            { assert(0); }
void foo2(immutable void* a) { assert(0); }
void foo2(immutable int* a)  { assert(0); }
void foo2(int[] a)           { assert(0); }
void foo2(void[] a)          { assert(0); }
void foo2(void delegate() a) { assert(0); }
void foo2(int[int] a)        { assert(0); }

// Prefer const conversion over polysemous conversion
void bar2(char[] a)            { assert(0); }
void bar2(const char[] a)      { assert("yay!"); }
void bar2(wchar[] a)           { assert(0); }
void bar2(const wchar[] a)     { assert(0); }
void bar2(immutable wchar[] a) { assert(0); }
void bar2(dchar[] a)           { assert(0); }
void bar2(const dchar[] a)     { assert(0); }
void bar2(immutable dchar[] a) { assert(0); }

void main() {

    auto n = null;
    auto s = "hello";

    foo(null);
    foo(n);

    bar("hello");
    bar(s);

    foo2(null);
    foo2(n);

    bar2("hello");
    bar2(s);
}
