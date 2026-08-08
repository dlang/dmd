import core.stdc.stdio : printf;

// ============================================================
// Section 0: Size/Offset Tests (compile-time static asserts)
// ============================================================

// All variants ≤1 byte: tag(ubyte=1) + union packs tightly
alias SmallTypes = __sumtype(bool | ubyte);
static assert(SmallTypes.sizeof == 2);  // tag(1) + union(1) = 2

alias SmallTypes2 = __sumtype(ubyte | ushort);
static assert(SmallTypes2.sizeof == 4); // tag(1) + pad(1) + union(2) = 4

alias SmallTypes3 = __sumtype(byte | short);
static assert(SmallTypes3.sizeof == 4); // tag(1) + pad(1) + union(2) = 4

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

    // bool variant - S1(true) creates int variant (bool->int implicit conversion)
    // so we test with a value we know is int
    auto r_bool = s_bool.match {
        (int x) => x + 1,
        (bool y) => 0
    };
    // S1(true) -> int 1, so r_bool == 2
    assert(r_bool == 2);
    printf("  dispatch bool-as-int: %d\n", r_bool);
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

    printf("\n=== All tests passed! ===\n");
    return 0;
}
