// C23 attribute-specifier-sequences in ImportC: every form below must parse.
// `deprecated` maps to D's `deprecated`; `noreturn` sets the function's `noreturn` flag
// (a backend codegen hint, not D's `noreturn` type — see dmd PR #12966, which added
// ImportC `__attribute__((noreturn))` this way). Every other standard, prefixed, or
// unknown attribute is accepted and ignored. The `attr` and `__attr__` spellings are
// equivalent.
//
// Spec references (N3220):
//   6.7.13    attribute-specifier-sequence syntax and placement
//   6.7.13.1  standard vs prefixed attributes; the `__attr__` spelling
//   6.7.13.2  attribute / attribute-list grammar; keyword attribute-tokens
//   6.7.13.5  deprecated          6.7.13.7  noreturn / _Noreturn
//   6.7.13.3  nodiscard           6.7.13.4  maybe_unused
//   6.7.13.6  fallthrough         6.7.13.8  unsequenced / reproducible
//   6.7.3.3   deprecated on an enumerator

// deprecated, with and without a message, incl. the __attr__ spelling
[[deprecated]] int d1(void);
[[deprecated("use d1")]] int d2(void);
[[__deprecated__]] int d3(void);

// noreturn / _Noreturn (a keyword used as an attribute-token)
[[noreturn]] void nr1(void);
[[_Noreturn]] void nr2(void);
[[__noreturn__]] void nr3(void);

// accepted and ignored
[[nodiscard]] int nd1(void);
[[nodiscard("keep it")]] int nd2(void);
[[maybe_unused]] static int mu1;
[[unsequenced]] int us1(void);
[[reproducible]] int rp1(void);

// attribute-prefixed-token (implementation-specific): accepted and ignored
[[gnu::always_inline]] int gp1(void);
[[clang::no_sanitize("address")]] int gp2(void);

// empty attribute specifier, empty attribute list, and a multi-attribute list
[[]] int e1(void);
[[,]] int e2(void);
[[deprecated, maybe_unused]] int m1(void);

// an attribute-specifier-sequence is one or more adjacent [[...]] specifiers
[[deprecated]] [[maybe_unused]] int d4(void);

// on a pointer declarator
int * [[gnu::aligned(8)]] p1;

// on a struct tag, before a member, and after a member declarator
struct [[deprecated("old")]] S
{
    [[maybe_unused]] int a;
    int b [[maybe_unused]];
};

// on enumerators (and a trailing comma)
enum E
{
    A [[deprecated("x")]],
    B [[maybe_unused]] = 5,
    C,
};

// on function parameters, both before and after the declarator
int f1(int x [[maybe_unused]], [[maybe_unused]] int y);

// at statement scope
int g(void)
{
    [[maybe_unused]] int local = 0;     // on a block-scope declaration
    switch (local)
    {
        case 0:
            ++local;
            [[fallthrough]];            // on a null statement
        case 1:
            break;
        default:
            break;
    }
    return local;
}
