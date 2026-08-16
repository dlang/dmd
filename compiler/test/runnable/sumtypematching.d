import core.stdc.stdio : printf;

// ============================================================
// Section 0: Size/Offset Tests (compile-time static asserts)
// ============================================================

// All variants ≤1 byte: tag(ubyte=1) + union packs tightly
alias SmallTypes = __sumtype(bool | ubyte);
static assert(SmallTypes.sizeof == 2);  // tag(1) + union(1) = 2

// A sumtype may have at most one integer type (char is not counted).
alias SmallTypes2 = __sumtype(char | ushort);
static assert(SmallTypes2.sizeof == 4); // tag(1) + pad(1) + union(2) = 4

alias SmallTypes3 = __sumtype(char | short);
static assert(SmallTypes3.sizeof == 4); // tag(1) + pad(1) + union(2) = 4

// char and int can coexist (char is not an "integer type" for the limit)
alias CharInt = __sumtype(char | int | bool);
static assert(CharInt.sizeof == 8);  // tag(1) + pad(3) + union(4) = 8

// Has >2 byte types: normal union alignment
alias LargeTypes = __sumtype(bool | int);
static assert(LargeTypes.sizeof == 8);  // tag(1) + pad(3) + union(4) = 8

// Empty struct variant (size=1, align=1)
struct Empty { }
alias WithEmpty = __sumtype(Empty | bool);
static assert(WithEmpty.sizeof == 2);   // tag(1) + union(1) = 2

alias WithEmptyLarge = __sumtype(Empty | int);
static assert(WithEmptyLarge.sizeof == 8); // tag(1) + pad(3) + union(4) = 8

// Tag is always at offset 0
static assert(SmallTypes.tupleof[0].offsetof == 0);

// ============================================================
// Section 0b: Default Variant / .init Tests
// ============================================================

struct NonZero
{
    int x = 42;
}

struct None {}

/// No None variant: default is first variant (tag=0)
alias Opt1 = __sumtype(NonZero | bool);
/// None is first: default is None (tag=0)
alias Opt2 = __sumtype(None | NonZero);
/// None is second: default is None (tag=1)
alias Opt3 = __sumtype(int | None);
/// None is last in a 3-variant sumtype: default is None (tag=2)
alias Opt4 = __sumtype(int | bool | None);

void testDefaultInit()
{
    // Opt1: tag=0, __v0 is NonZero with default fields
    Opt1 o1;
    assert(o1.tag == 0);
    assert(o1.__v0.x == 42);
    printf("  default init (no None): tag=%d x=%d\n", o1.tag, o1.__v0.x);

    // Opt2: tag=0 (None), __v1 is uninitialized
    Opt2 o2;
    assert(o2.tag == 0);
    printf("  default init (None first): tag=%d\n", o2.tag);

    // Opt3: tag=1 (None is second)
    Opt3 o3;
    assert(o3.tag == 1);
    printf("  default init (None second): tag=%d\n", o3.tag);

    // Opt4: tag=2 (None is last)
    Opt4 o4;
    assert(o4.tag == 2);
    printf("  default init (None last): tag=%d\n", o4.tag);

    // Explicitly construct NonZero variant
    Opt2 o2b = Opt2(NonZero(100));
    assert(o2b.tag == 1);
    assert(o2b.__v1.x == 100);
    printf("  explicit NonZero: tag=%d x=%d\n", o2b.tag, o2b.__v1.x);

    // Verify __traits(initSymbol) matches the default .init
    auto init1 = *cast(Opt1*) __traits(initSymbol, Opt1).ptr;
    assert(init1.tag == 0);
    assert(init1.__v0.x == 42);
    printf("  initSymbol Opt1: tag=%d x=%d\n", init1.tag, init1.__v0.x);

    auto init2 = __traits(initSymbol, Opt2);
    assert(init2.ptr is null);
    assert(init2.length == 8);

    auto init3 = *cast(Opt3*) __traits(initSymbol, Opt3).ptr;
    assert(init3.tag == 1);
    printf("  initSymbol Opt3: tag=%d\n", init3.tag);

    auto init4 = *cast(Opt4*) __traits(initSymbol, Opt4).ptr;
    assert(init4.tag == 2);
    printf("  initSymbol Opt4: tag=%d\n", init4.tag);
}

// ============================================================
// Section 1: Sumtype Declarations
// ============================================================

/// Form 1: Alias form (unnamed variants)
alias S1 = __sumtype(int | bool);
alias S2 = __sumtype(int | bool | string);
alias S3 = __sumtype(int);

/// Form 2: Named declaration form (named variants)
__sumtype Named = int x | bool y;

// ============================================================
// Section 2: Constructors
// ============================================================

void testConstructors()
{
    // Type-inferred constructor (unnamed variants)
    S1 s1a = S1(42);
    assert(s1a.tag == 0);
    assert(s1a.__v0 == 42);
    printf("  constructor type-inferred: tag=%d val=%d\n", s1a.tag, s1a.__v0);

    // Named variant constructor
    Named n1 = Named(x: 10);
    assert(n1.tag == 0);
    assert(n1.x == 10);
    printf("  constructor named x: tag=%d val=%d\n", n1.tag, n1.x);

    Named n2 = Named(y: true);
    assert(n2.tag == 1);
    assert(n2.y == true);
    printf("  constructor named y: tag=%d val=%d\n", n2.tag, n2.y);

    // 3-variant constructor
    S2 s2a = S2(100);
    assert(s2a.tag == 0);
    assert(s2a.__v0 == 100);
    printf("  constructor 3-variant int: tag=%d val=%d\n", s2a.tag, s2a.__v0);

    S2 s2b = S2("hello");
    assert(s2b.tag == 2);
    printf("  constructor 3-variant string: tag=%d\n", s2b.tag);

    // Single-variant degenerates to alias S3 = int
    S3 s3 = S3(7);
    assert(s3 == 7);
    printf("  constructor single-variant (alias): val=%d\n", s3);
}

// ============================================================
// Section 3: Tag and Field Access
// ============================================================

void testFieldAccess()
{
    S1 s = S1(99);
    assert(s.tag == 0);
    assert(s.__v0 == 99);
    printf("  field access unnamed: tag=%d val=%d\n", s.tag, s.__v0);

    Named n = Named(y: false);
    assert(n.tag == 1);
    assert(n.y == false);
    printf("  field access named: tag=%d y=%d\n", n.tag, n.y);

    // Named variant field also accessible via variant name
    assert(n.y == false);
    printf("  field access by variant name: y=%d\n", n.y);
}

// ============================================================
// Section 4: Match Expressions
// ============================================================

void testMatchBasic()
{
    S1 s = S1(21);

    // Basic match - int variant
    auto r = s.match {
        (int x) => x * 2,
        (bool y) => y ? 1 : 0
    };
    assert(r == 42);
    printf("  match basic int: %d\n", r);
}

void testMatchMultiVariant()
{
    S2 s = S2("world");

    // Match with 3 variants
    auto r = s.match {
        (int x) => x + 1,
        (bool y) => 99,
        (string z) => cast(int) z.length
    };
    assert(r == 5); // "world".length == 5
    printf("  match multi-variant: %d\n", r);
}

void testMatchExpressions()
{
    S1 s = S1(10);

    // Match arm body can be any expression
    auto r = s.match {
        (int x) => x > 5 ? x * 3 : x,
        (bool y) => 0
    };
    assert(r == 30);
    printf("  match complex expression: %d\n", r);
}

void testMatchResultUsedInExpression()
{
    S1 s = S1(5);

    // Match result used directly in expression context
    assert(s.match { (int x) => x + 1, (bool y) => 0 } == 6);
    printf("  match result in expression: OK\n");
}

// ============================================================
// Section 5: Exhaustiveness Checking
// ============================================================

// Non-exhaustive match (compile error):
// S1 s = S1(1);
// auto r = s.match { (int x) => x };  // missing bool arm

// Redundant catch-all (compile error):
// S1 s = S1(1);
// auto r = s.match { (int x) => x, (bool y) => 1, (z) => 0 };

// ============================================================
// Section 6: Catch-all Arms (Typeless)
// ============================================================

void testCatchAll()
{
    S2 s = S2(42);

    // Catch-all matches any variant
    auto r = s.match {
        (int x) => x * 2,
        (y) => -1  // catch-all: y is bool or string depending on variant
    };
    assert(r == 84); // int variant matched
    printf("  catch-all int: %d\n", r);

    S2 s2 = S2("hello");
    auto r2 = s2.match {
        (int x) => x * 2,
        (y) => -1  // catch-all: matches string variant
    };
    assert(r2 == -1); // catch-all matched
    printf("  catch-all string: %d\n", r2);
}

// ============================================================
// Section 7: Cross-Sumtype Assignment
// ============================================================

void testCrossSumtypeAssignment()
{
    S1 s1 = S1(55);
    S2 s3 = s1; // implicit conversion via match
    assert(s3.tag == 0);
    assert(s3.__v0 == 55);
    printf("  cross-sumtype init: tag=%d val=%d\n", s3.tag, s3.__v0);

    s3 = s1; // assignment
    assert(s3.tag == 0);
    assert(s3.__v0 == 55);
    printf("  cross-sumtype assign: tag=%d val=%d\n", s3.tag, s3.__v0);
}

// ============================================================
// Section 7b: Widening Support
// A narrower sumtype is implicitly convertible to a wider sumtype
// (one that contains all of its variants), for return values,
// function call arguments, and argument-to-parameter matching.
// ============================================================

// Return widening: returning a narrower sumtype from a function
// whose return type is a wider sumtype
S2 returnWidenNarrow() { return S1(42); }
S2 returnWidenBool() { return S1(true); }

// Function call widening: passing a narrower sumtype to a parameter
// expecting a wider sumtype
void takeWide(S2 s) { }

// Argument-to-parameter matching when widening is not an exact match
// must still resolve (the argument is a narrower sumtype, the parameter
// is a wider sumtype)
int takeWideAndMatch(S2 s)
{
    return s.match {
        (int x) => x * 2,
        (bool y) => y ? 1 : 0,
        (string z) => cast(int) z.length
    };
}

void testWidening()
{
    // Return widening: int variant
    S2 r1 = returnWidenNarrow();
    assert(r1.tag == 0);
    assert(r1.__v0 == 42);
    printf("  return widen int: tag=%d val=%d\n", r1.tag, r1.__v0);

    // Return widening: bool variant keeps its own tag
    S2 r2 = returnWidenBool();
    assert(r2.tag == 1);
    assert(r2.__v1 == true);
    printf("  return widen bool: tag=%d val=%d\n", r2.tag, r2.__v1);

    // Function call widening: narrower sumtype argument to wider sumtype parameter
    takeWide(S1(7));
    takeWide(returnWidenNarrow());
    printf("  call widen: ok\n");

    // Argument-to-parameter matching with widening (not an exact match)
    assert(takeWideAndMatch(S1(21)) == 42);
    assert(takeWideAndMatch(S1(true)) == 1);
    printf("  call widen match: ok\n");
}

// ============================================================
// Section 8: Auto-tag Assignment (Named Variants)
// ============================================================

void testAutoTagAssignment()
{
    Named n = Named(x: 1);
    assert(n.tag == 0);

    // Assigning to named variant field auto-sets the tag
    n.y = true;
    assert(n.tag == 1);
    assert(n.y == true);
    printf("  auto-tag assign: tag=%d y=%d\n", n.tag, n.y);

    n.x = 42;
    assert(n.tag == 0);
    assert(n.x == 42);
    printf("  auto-tag reassign: tag=%d x=%d\n", n.tag, n.x);
}

// ============================================================
// Section 9: Match Dispatch
// ============================================================

void testMatchDispatch()
{
    S1 s_int = S1(100);
    S1 s_bool = S1(true);

    // int variant
    auto r_int = s_int.match {
        (int x) => x + 1,
        (bool y) => 0
    };
    assert(r_int == 101);
    printf("  dispatch int: %d\n", r_int);

    // S1(true) now creates the bool variant (exact match preferred over
    // the bool->int implicit conversion)
    auto r_bool = s_bool.match {
        (int x) => x + 1,
        (bool y) => 0
    };
    // S1(true) -> bool variant, so r_bool == 0
    assert(r_bool == 0);
    printf("  dispatch bool: %d\n", r_bool);
}

// ============================================================
// Section 10: Multiple Match Expressions in Same Scope
// ============================================================

void testMultipleMatches()
{
    S1 s1 = S1(10);
    S1 s2 = S1(20);

    auto r1 = s1.match {
        (int x) => x * 2,
        (bool y) => 0
    };
    auto r2 = s2.match {
        (int x) => x + 5,
        (bool y) => 0
    };
    assert(r1 == 20);
    assert(r2 == 25);
    printf("  multiple matches: r1=%d r2=%d\n", r1, r2);
}

// ============================================================
// Section 11: By-ref Match Parameters
// ============================================================

void testByRefMatch()
{
    S1 s = S1(10);

    // Non-ref: parameter is a copy, original unchanged
    auto r1 = s.match {
        (int x) => x * 2,
        (bool y) => 0
    };
    assert(r1 == 20);
    assert(s.__v0 == 10); // original unchanged
    printf("  non-ref no mutation: val=%d\n", s.__v0);

    // ref: parameter binds to storage, modification visible
    s.match {
        (ref int x) => (x = 99, 0),
        (bool y) => 0
    };
    assert(s.__v0 == 99); // original WAS modified via ref
    printf("  ref mutation visible: val=%d\n", s.__v0);

    // Verify ref doesn't affect other variants
    Named n = Named(x: 1);
    n.match {
        (ref int x) => (x = 50, 0),
        (bool y) => 0
    };
    assert(n.tag == 0); // tag unchanged
    assert(n.x == 50);    // value changed via ref
    printf("  ref named variant: tag=%d x=%d\n", n.tag, n.x);

    // Non-ref on named variant: no mutation
    Named n2 = Named(y: true);
    auto r2 = n2.match {
        (int x) => x,
        (bool y) => y ? 1 : 0
    };
    assert(r2 == 1);
    assert(n2.y == true); // unchanged
    printf("  non-ref named: y=%d\n", n2.y);

    // ref catch-all: catch-all matches the unmatched variant
    __sumtype RefTest = int a | bool b;
    RefTest rt = RefTest(b: true);
    assert(rt.tag == 1);
    rt.match {
        (int x) => 0,
        (ref y) => (y = false, 0)  // catch-all ref on bool variant: y is ref bool
    };
    assert(rt.tag == 1);    // tag unchanged
    assert(rt.b == false);    // bool variant value changed via ref
    printf("  ref catch-all on bool: tag=%d b=%d\n", rt.tag, rt.b);
}

// ============================================================
// Section 12: Default Init
// ============================================================

void testDefaultInit2()
{
    // Alias form (unnamed variants)
    alias S1 = __sumtype(int | bool);
    S1 s;
    assert(s.tag == 0);
    assert(s.__v0 == 0);
    printf("  default init S1: tag=%d val=%d\n", s.tag, s.__v0);
}

// ============================================================
// Section 13: Guard Expressions
// ============================================================

void testGuardBasic()
{
    S1 s = S1(42);

    // Guard true: takes guarded arm
    auto r1 = s.match {
        (int v) if (v > 0) => v,
        (int v) => -v,
        (bool b) => 0
    };
    assert(r1 == 42);
    printf("  guard basic (true): %d\n", r1);

    // Guard false: falls through to unguarded arm
    S1 s2 = S1(-10);
    auto r2 = s2.match {
        (int v) if (v > 0) => v,
        (int v) => -v,
        (bool b) => 0
    };
    assert(r2 == 10);
    printf("  guard basic (false): %d\n", r2);
}

void testGuardWithCatchAll()
{
    S1 s = S1(5);

    // Guard fails, falls through to catch-all
    auto r = s.match {
        (int v) if (v > 100) => v,
        (z) => -1
    };
    assert(r == -1);
    printf("  guard with catch-all: %d\n", r);

    // Guard passes, catch-all not reached
    S1 s2 = S1(200);
    auto r2 = s2.match {
        (int v) if (v > 100) => v,
        (z) => -1
    };
    assert(r2 == 200);
    printf("  guard with catch-all (pass): %d\n", r2);
}

void testGuardNamedVariants()
{
    __sumtype NS = int a | bool b;

    // Guard on named bool variant
    NS s1 = NS(b: true);
    auto r1 = s1.match {
        (int v) => v,
        (bool b) if (b) => 10,
        (bool b) => 20
    };
    assert(r1 == 10);
    printf("  guard named (true): %d\n", r1);

    NS s2 = NS(b: false);
    auto r2 = s2.match {
        (int v) => v,
        (bool b) if (b) => 10,
        (bool b) => 20
    };
    assert(r2 == 20);
    printf("  guard named (false): %d\n", r2);
}

void testGuardMultipleForSameVariant()
{
    S1 s = S1(5);

    // Two guarded arms for int variant + unguarded fallback
    auto r = s.match {
        (int v) if (v > 100) => 1,
        (int v) if (v > 0) => 2,
        (int v) => 3,
        (bool b) => 0
    };
    assert(r == 2); // v=5, >0 but not >100
    printf("  guard multiple (second): %d\n", r);

    // First guard matches
    S1 s2 = S1(200);
    auto r2 = s2.match {
        (int v) if (v > 100) => 1,
        (int v) if (v > 0) => 2,
        (int v) => 3,
        (bool b) => 0
    };
    assert(r2 == 1);
    printf("  guard multiple (first): %d\n", r2);

    // No guard matches
    S1 s3 = S1(-5);
    auto r3 = s3.match {
        (int v) if (v > 100) => 1,
        (int v) if (v > 0) => 2,
        (int v) => 3,
        (bool b) => 0
    };
    assert(r3 == 3);
    printf("  guard multiple (fallback): %d\n", r3);
}

void testGuardCatchAllWithGuardedTyped()
{
    // Catch-all used when all typed arms for a variant are guarded
    S1 s = S1(5);
    auto r = s.match {
        (int v) if (v > 100) => v,
        (z) => -1  // catch-all: reached when int guard fails
    };
    assert(r == -1);
    printf("  guard catch-all fallback: %d\n", r);

    // Guard passes, catch-all not reached
    S1 s2 = S1(200);
    auto r2 = s2.match {
        (int v) if (v > 100) => v,
        (z) => -1
    };
    assert(r2 == 200);
    printf("  guard catch-all pass: %d\n", r2);
}

// ============================================================
// Section 14: UDA Propagation
// ============================================================

alias SUDAs = __sumtype(@(1) None | bool);
static assert(__traits(getAttributes, SUDAs.__v0).length == 1);
static assert(__traits(getAttributes, SUDAs.__v0)[0] == 1);
static assert(__traits(getAttributes, SUDAs.__v1).length == 0);

// ============================================================
// Section 14b: `match` as Identifier (not a keyword)
// ============================================================

int match(int x) { return x + 1; }

void testMatchAsIdentifier()
{
    // match as function name
    assert(match(10) == 11);
    printf("  match as function: %d\n", match(10));

    // match as template function
    auto r = match(5);
    assert(r == 6);
    printf("  match as template function: %d\n", r);

    // match as variable name
    int match = 42;
    assert(match == 42);
    printf("  match as variable: %d\n", match);
}

// ============================================================
// Section 15: Lifecycle Hooks
// ============================================================

int copyCount, moveCount, postBlitCount, destroyCount;

struct Copier {
    int val;
    this(ref Copier other) {
        copyCount++;
        val = other.val;
    }
    ~this() {
        destroyCount++;
    }
}

struct PostBlit {
    int val;
    this(this) {
        postBlitCount++;
    }
    ~this() {
        destroyCount++;
    }
}

struct Tracked {
    int val;
    this(this) {
        postBlitCount++;
    }
    ~this() {
        destroyCount++;
    }
}

alias LS1 = __sumtype(Copier | int);
alias LS2 = __sumtype(PostBlit | int);
alias LS3 = __sumtype(Tracked | int);

void testAssignCopy()
{
    copyCount = 0;
    destroyCount = 0;

    {
        LS1 original = LS1(Copier(10));
        LS1 copy = original; // copy construction

        assert(copyCount == 1);
    }

    assert(destroyCount == 2);
    printf("  [assign-copy] copyCount=%d destroyCount=%d\n", copyCount, destroyCount);
}

void testAssignPostBlit()
{
    postBlitCount = 0;
    destroyCount = 0;

    {
        LS2 original = LS2(PostBlit(30));
        LS2 copy = original; // postblit

        assert(postBlitCount == 1);
    }

    assert(destroyCount == 2);
    printf("  [assign-postblit] postBlitCount=%d destroyCount=%d\n", postBlitCount, destroyCount);
}

void testMatchCopy()
{
    copyCount = 0;
    destroyCount = 0;

    {
        LS1 s = LS1(Copier(40));
        auto result = s.match {
            (Copier c) => c.val * 2,
            (int i) => i
        };

        assert(result == 80);
        assert(copyCount == 1);
    }

    assert(destroyCount == 2);
    printf("  [match-copy] result=%d copyCount=%d destroyCount=%d\n", 80, copyCount, destroyCount);
}

void testMatchPostBlit()
{
    postBlitCount = 0;
    destroyCount = 0;

    {
        LS2 s = LS2(PostBlit(60));
        auto result = s.match {
            (PostBlit p) => p.val + 10,
            (int i) => i
        };

        assert(result == 70);
        assert(postBlitCount == 1);
    }

    assert(destroyCount == 2);
    printf("  [match-postblit] result=%d postBlitCount=%d destroyCount=%d\n", 70, postBlitCount, destroyCount);
}

void testMatchRefNoCopy()
{
    postBlitCount = 0;
    destroyCount = 0;

    {
        LS3 s = LS3(Tracked(70));
        s.match {
            (ref Tracked t) => (t.val = 99, 0),
            (int i) => 0
        };

        assert(postBlitCount == 0);
    }

    assert(destroyCount == 1);
    printf("  [match-ref-nocopy] postBlitCount=%d destroyCount=%d\n", postBlitCount, destroyCount);
}

void testMultiLifecycle()
{
    postBlitCount = 0;
    destroyCount = 0;

    {
        LS2 a = LS2(PostBlit(1));
        LS2 b = LS2(PostBlit(2));
        LS2 c = a; // copy/postblit
        c = b;    // assign (destroy old c, copy b)

        assert(postBlitCount == 2);
    }
    // All three destroyed
    assert(destroyCount == 4);
    printf("  [multi-lifecycle] postBlitCount=%d destroyCount=%d\n", postBlitCount, destroyCount);
}

void testCrossSumtypeLifecycle()
{
    postBlitCount = 0;
    destroyCount = 0;

    alias CST1 = __sumtype(PostBlit | int);
    alias CST2 = __sumtype(PostBlit | int | string);

    {
        CST1 a = CST1(PostBlit(100));
        CST2 b = a; // cross-sumtype: builds match, creates PostBlit copy

        assert(postBlitCount == 1);
    }

    assert(destroyCount == 2);
    printf("  [cross-sumtype-lifecycle] postBlitCount=%d destroyCount=%d\n", postBlitCount, destroyCount);
}

void testDestroyBeforeAssign()
{
    alias ST = __sumtype(Copier | int);

    destroyCount = 0;
    copyCount = 0;

    ST a = ST(Copier());
    ST b = a;
    a = b;

    assert(copyCount == 2);
    assert(destroyCount == 1);
    printf("  [destroy-before-assign] copyCount=%d destroyCount=%d\n", copyCount, destroyCount);
}

// ============================================================
// Section 16: opCmp / toHash
// ============================================================
void testOpCmpToHash()
{
    alias S = __sumtype(int | string);

    // Generated toHash and opCmp exist for an orderable, hashable sum.
    static assert(__traits(hasMember, S, "toHash"));
    static assert(__traits(hasMember, S, "opCmp"));

    // opCmp orders by tag first, then by the active variant's value.
    assert(S(1) < S(2));
    assert(S(2) < S(3));
    assert(!(S(2) < S(1)));
    assert(S("a") < S("b"));
    assert(S(1) <= S(1));
    assert(S(1) >= S(1));
    assert(S(0) < S("a"));  // int tag (0) < string tag (1)
    assert(S("a") > S(1));
    assert(!(S("a") < S(1)));

    // toHash is deterministic and consistent with equality.
    assert(hashOf(S(3)) == hashOf(S(3)));
    assert(hashOf(S("a")) == hashOf(S("a")));

    // Sumtype used as an AA key.
    int[S] aa;
    aa[S(1)]   = 10;
    aa[S(2)]   = 20;
    aa[S("a")] = 30;
    aa[S("b")] = 40;
    assert(aa.length == 4);
    assert(aa[S(1)]   == 10);
    assert(aa[S(2)]   == 20);
    assert(aa[S("a")] == 30);
    assert(aa[S("b")] == 40);
    assert(!(S(3) in aa));
    assert(S(1) in aa);
    aa[S(2)] = 21; // overwrite existing key
    assert(aa[S(2)] == 21);

    // A variant aggregate with an @disable`d toHash prevents generation of toHash.
    struct DisHash { int x; @disable size_t toHash() const; }
    alias NoHash = __sumtype(int | DisHash);
    static assert(!__traits(hasMember, NoHash, "toHash"));

    // A variant aggregate with an @disable`d opCmp (or that lacks opCmp)
    // prevents generation of opCmp. toHash is still generated.
    struct DisCmp { int x; @disable int opCmp(ref const DisCmp) const; }
    alias NoCmp    = __sumtype(int | DisCmp);
    alias BoolSum  = __sumtype(int | bool);
    static assert(!__traits(hasMember, NoCmp,   "opCmp"));
    static assert( __traits(hasMember, BoolSum, "opCmp"));
    static assert( __traits(hasMember, BoolSum, "toHash"));

    // bool variants are orderable (false < true), so opCmp is generated and
    // orders by tag first, then by the active variant's value.
    assert(BoolSum(0) < BoolSum(1));
    assert(BoolSum(false) < BoolSum(true));
    assert(!(BoolSum(true) < BoolSum(false)));
    assert(BoolSum(1) < BoolSum(false)); // int tag (0) < bool tag (1)

    printf("  [opcmp-tohash] ok\n");
}

// ============================================================
// Section 17: is(T == __sumtype) detection
// ============================================================
void testIsSumType()
{
    alias S = __sumtype(int | string);
    alias Other = int;

    static assert(is(S == __sumtype));
    static assert(!is(Other == __sumtype));
    static assert(!is(int == __sumtype));

    struct NotSumType {}
    static assert(!is(NotSumType == __sumtype));

    // Works through a template parameter too.
    bool isSum(T)() => is(T == __sumtype);
    static assert(isSum!S());

    // Named declaration form.
    __sumtype Named = int x | bool y;
    static assert(is(Named == __sumtype));

    // Single-variant sumtypes degenerate to a plain alias of the wrapped type.
    alias Single = __sumtype(int);
    static assert(!is(Single == __sumtype));
    static assert(is(Single == int));

    printf("  [is-sumtype] ok\n");
}

// ============================================================
// Section 18: Templates and Alias Sequences
// ============================================================
// A sumtype may be declared as a template. The alias sequence parameter
// auto-expands into its component types:
//   __sumtype S(Types...) = Types | bool;
//   S!(int, string)  ==  __sumtype(int | string | bool)
void testTemplatesAndAliasSequences()
{
    // Template declaration form.
    __sumtype Tpl(Types...) = Types | bool;

    // Types=(int, string) auto-expands into the variants int, string, bool.
    // Members: tag + 3 variant fields + toHash + opCmp (bool is orderable) = 6.
    static assert(__traits(allMembers, Tpl!(int, string)).length == 6);
    static assert(__traits(allMembers, Tpl!(int, string))[0] == "tag");
    static assert(__traits(allMembers, Tpl!(int, string))[1] == "__v0");
    static assert(__traits(allMembers, Tpl!(int, string))[4] == "toHash");
    static assert(__traits(allMembers, Tpl!(int, string))[5] == "opCmp");

    // Construction of each expanded variant.
    Tpl!(int, string) a = Tpl!(int, string)(42);
    assert(a.tag == 0 && a.__v0 == 42);

    Tpl!(int, string) b = Tpl!(int, string)("hello");
    assert(b.tag == 1 && b.__v1 == "hello");

    Tpl!(int, string) c = Tpl!(int, string)(true);
    assert(c.tag == 2 && c.__v2 == true);

    // match over all expanded variants.
    auto r = b.match {
        (int x) => x + 1,
        (string s) => cast(int) s.length,
        (bool z) => 0
    };
    assert(r == 5);
    printf("  template alias seq match: %d\n", r);

    // Each instantiation is independent: S!(long, double) must not reuse
    // the variant set resolved for S!(int, string).
    Tpl!(long, double) d = Tpl!(long, double)(7L);
    assert(d.tag == 0 && d.__v0 == 7L);
    Tpl!(long, double) e = Tpl!(long, double)(3.5);
    assert(e.tag == 1 && e.__v1 == 3.5);
    Tpl!(long, double) f = Tpl!(long, double)(false);
    assert(f.tag == 2 && f.__v2 == false);

    // A template sumtype is recognized as a sumtype.
    static assert(is(Tpl!(int, string) == __sumtype));

    // Generated members match the non-template form. `int | string | bool`
    // generates opCmp (bool is orderable) and toHash; no copy ctor because
    // none of the variants require one for safe copying (all are POD).
    alias DirectTpl = __sumtype(int | string | bool);
    static assert(__traits(allMembers, DirectTpl).length == 6);
    static assert(__traits(hasMember, DirectTpl, "opCmp"));
    static assert(!__traits(hasMember, DirectTpl, "__ctor"));
    static assert( __traits(hasMember, DirectTpl, "toHash"));
    static assert(__traits(hasMember, Tpl!(int, string), "opCmp"));
    static assert(!__traits(hasMember, Tpl!(int, string), "__ctor"));
    static assert( __traits(hasMember, Tpl!(int, string), "toHash"));

    // Without a bool variant, opCmp is generated.
    __sumtype Tpl2(Types...) = Types;
    alias TSI = Tpl2!(string, int);
    static assert(__traits(hasMember, TSI, "opCmp"));
    static assert(__traits(hasMember, TSI, "toHash"));
    static assert(__traits(allMembers, TSI).length == 5);

    // A variant with a copy constructor forces `__ctor` generation.
    alias TC = Tpl2!(Copier, int);
    static assert(__traits(hasMember, TC, "__ctor"));
    static assert(__traits(hasMember, TC, "opAssign"));

    // The standard alias-template form also works with per-instantiation state.
    struct None {}
    alias Option(T) = __sumtype(T | None);
    Option!int oi = Option!int(42);
    assert(oi.tag == 0 && oi.__v0 == 42);
    Option!string os = Option!string("hi");
    assert(os.tag == 0 && os.__v0 == "hi");
    assert(__traits(allMembers, Option!int).length == 4);
    assert(__traits(allMembers, Option!string).length == 4);

    printf("  [templates-alias-seq] ok\n");
}

// ============================================================
// Main
// ============================================================

extern(C) int main()
{
    printf("=== Sumtype Test Suite ===\n");

    printf("[1] Constructors\n");
    testConstructors();

    printf("[2] Field Access\n");
    testFieldAccess();

    printf("[3] Match Basic\n");
    testMatchBasic();

    printf("[4] Match Multi-Variant\n");
    testMatchMultiVariant();

    printf("[5] Match Complex Expressions\n");
    testMatchExpressions();

    printf("[6] Match Result in Expression\n");
    testMatchResultUsedInExpression();

    printf("[7] Catch-all Arms\n");
    testCatchAll();

    printf("[8] Cross-Sumtype Assignment\n");
    testCrossSumtypeAssignment();

    printf("[8b] Widening Support\n");
    testWidening();

    printf("[9] Auto-tag Assignment\n");
    testAutoTagAssignment();

    printf("[10] Match Dispatch\n");
    testMatchDispatch();

    printf("[11] Multiple Matches\n");
    testMultipleMatches();

    printf("[12] By-ref Match Parameters\n");
    testByRefMatch();

    printf("[13] Default Init\n");
    testDefaultInit();

    printf("[14] Guard Expressions\n");
    testGuardBasic();
    testGuardWithCatchAll();
    testGuardNamedVariants();
    testGuardMultipleForSameVariant();
    testGuardCatchAllWithGuardedTyped();

    printf("[14b] Match as Identifier\n");
    testMatchAsIdentifier();

    printf("[15] Lifecycle Hooks\n");
    testAssignCopy();
    testAssignPostBlit();
    testMatchCopy();
    testMatchPostBlit();
    testMatchRefNoCopy();
    testMultiLifecycle();
    testCrossSumtypeLifecycle();
    testDestroyBeforeAssign();

    printf("[16] opCmp / toHash\n");
    testOpCmpToHash();

    printf("[17] is(T == __sumtype)\n");
    testIsSumType();

    printf("[18] Templates and Alias Sequences\n");
    testTemplatesAndAliasSequences();

    printf("\n=== All tests passed! ===\n");
    return 0;
}
