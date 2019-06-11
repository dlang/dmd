/*
 * Test C++ abi-tag name mangling.
 * https://issues.dlang.org/show_bug.cgi?id=19949
 */

// Requires at minimum Clang 3.9 or GCC 5

#define foo_bar [[gnu::abi_tag("foo", "bar")]]

struct foo_bar S
{
public:
    int i;
    S(int);
};

S::S(int i) : i(i) {}

foo_bar
int a;

S b(0);

foo_bar
int f() { return 0xf; }

S gs(int i) { return S(i + 0xe0); }
S gss(S s, int i) { return S(i + s.i + 0xe0); }

foo_bar
S fss(S s, int i) { return S(i + s.i + 0xf); }

template <class T>
T gt(int i) { return T(i + 0xe0); }

template <class T>
T gtt(T t, int i) { return T(i + t.i + 0xe0); }


template <class T>
foo_bar /* GCC is inconsistent here, <= 6 matches clang but >= 7 is different */
T ft(int i) { return T(i + 0xf); }

template <class T>
foo_bar /* GCC is inconsistent here, <= 6 matches clang but >= 7 is different */
T ftt(T t, int i) { return T(i + t.i + 0xf); }

#ifdef __clang__
inline namespace [[gnu::abi_tag("AAA")]] N
#else
inline namespace N [[gnu::abi_tag("AAA")]]
#endif
{
    template <int>
    struct [[gnu::abi_tag("foo", "bar")]] K
    {
    public:
        int i;
        K(int i);
    };
}

template <int j>
K<j>::K(int i) : i(i) {}

template <int j>
K<j> fk(int i) { return K<j>(i + j + 0xf); }

K<1> fk1(int i) { return K<1>(i + 1 + 0xf); }

K<10> k10(0);

void initVars()
{
    a = 10;
    b = S(20);
    k10 = K<10>(30);
}

// doesn't compile on Clang or GCC < 6
#if __GNUC__ >= 6
enum [[gnu::abi_tag("ENN")]] E0
{ E0a = 0xa };

E0 fe() { return E0a; }

template<int>
E0 fei() { return E0a; }
#endif

void instatiate()
{
    gt<S>(1);
    gtt<S>(S(1), 1);
    ft<S>(1);
    ftt<S>(S(1), 1);
    fk<0>(1);
#if __GNUC__ >= 6
    fei<0>();
#endif
}

#ifdef __linux__
#include <string>
std::string* toString(const char* s)
{
    return new std::string(s);
}
#endif
