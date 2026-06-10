// C23 6.7.13 attribute-specifier-sequences in ImportC.
// All forms below must parse; `deprecated` (6.7.13.5) and `noreturn` (6.7.13.7) map to
// the D equivalents, every other standard, prefixed, or unknown attribute is accepted
// and ignored (N3220 6.7.13.1).

// C23 6.7.13.5 deprecated, with and without a message, incl. the __attr__ spelling (6.7.13.1)
[[deprecated]] int d1(void);
[[deprecated("use d1")]] int d2(void);
[[__deprecated__]] int d3(void);

// C23 6.7.13.7 noreturn / _Noreturn (a keyword used as an attribute-token, 6.7.13.2)
[[noreturn]] void nr1(void);
[[_Noreturn]] void nr2(void);
[[__noreturn__]] void nr3(void);

// C23 6.7.13.3/.4/.8 accepted and ignored
[[nodiscard]] int nd1(void);
[[nodiscard("keep it")]] int nd2(void);
[[maybe_unused]] static int mu1;
[[unsequenced]] int us1(void);
[[reproducible]] int rp1(void);

// C23 6.7.13.1 attribute-prefixed-token (implementation-specific): accepted and ignored
[[gnu::always_inline]] int gp1(void);
[[clang::no_sanitize("address")]] int gp2(void);

// C23 6.7.13.2 empty attribute specifier, empty attribute list, and a multi-attribute list
[[]] int e1(void);
[[,]] int e2(void);
[[deprecated, maybe_unused]] int m1(void);

// C23 6.7.13 on a pointer declarator
int * [[gnu::aligned(8)]] p1;

// C23 6.7.13 on a struct tag, before a member, and after a member declarator
struct [[deprecated("old")]] S
{
    [[maybe_unused]] int a;
    int b [[maybe_unused]];
};

// C23 6.7.3.3 / 6.7.13 attributes on enumerators (and a trailing comma)
enum E
{
    A [[deprecated("x")]],
    B [[maybe_unused]] = 5,
    C,
};

// C23 6.7.13 on function parameters, both before and after the declarator
int f1(int x [[maybe_unused]], [[maybe_unused]] int y);

// C23 6.7.13 at statement scope
int g(void)
{
    [[maybe_unused]] int local = 0;     // on a block-scope declaration
    switch (local)
    {
        case 0:
            ++local;
            [[fallthrough]];            // C23 6.7.13.6 on a null statement
        case 1:
            break;
        default:
            break;
    }
    return local;
}
