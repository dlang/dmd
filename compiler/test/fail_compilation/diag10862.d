/*
TEST_OUTPUT:
---
fail_compilation/diag10862.d(86): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    if (a = b) {}
          ^
fail_compilation/diag10862.d(87): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    if ((a = b) = 0) {}
                ^
fail_compilation/diag10862.d(88): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    if ((a = b) = (a = b)) {}
                ^
fail_compilation/diag10862.d(89): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    if (a = 0, b = 0) {}        // https://issues.dlang.org/show_bug.cgi?id=15384
                 ^
fail_compilation/diag10862.d(90): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    if (auto x = a = b) {}      // this is error, today
                   ^
fail_compilation/diag10862.d(92): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    while (a = b) {}
             ^
fail_compilation/diag10862.d(93): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    while ((a = b) = 0) {}
                   ^
fail_compilation/diag10862.d(94): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    while ((a = b) = (a = b)) {}
                   ^
fail_compilation/diag10862.d(95): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    while (a = 0, b = 0) {}     // https://issues.dlang.org/show_bug.cgi?id=15384
                    ^
fail_compilation/diag10862.d(97): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    do {} while (a = b);
                   ^
fail_compilation/diag10862.d(98): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    do {} while ((a = b) = 0);
                         ^
fail_compilation/diag10862.d(99): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    do {} while ((a = b) = (a = b));
                         ^
fail_compilation/diag10862.d(100): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    do {} while (a = 0, b = 0); // https://issues.dlang.org/show_bug.cgi?id=15384
                          ^
fail_compilation/diag10862.d(102): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    for (;  a = b; ) {}
              ^
fail_compilation/diag10862.d(103): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    for (;  (a = b) = 0; ) {}
                    ^
fail_compilation/diag10862.d(104): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    for (;  (a = b) = (a = b); ) {}
                    ^
fail_compilation/diag10862.d(105): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    for (;  a = 0, b = 0; ) {}  // https://issues.dlang.org/show_bug.cgi?id=15384
                     ^
fail_compilation/diag10862.d(107): Error: undefined identifier `semanticError`
    semanticError;
    ^
fail_compilation/diag10862.d(117): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    if (a + b = a * b) {}
              ^
fail_compilation/diag10862.d(120): Error: assignment cannot be used as a condition, perhaps `==` was meant?
    if (a = undefinedIdentifier) {}
          ^
fail_compilation/diag10862.d-mixin-123(123): Error: assignment cannot be used as a condition, perhaps `==` was meant?
fail_compilation/diag10862.d-mixin-124(124): Error: assignment cannot be used as a condition, perhaps `==` was meant?
fail_compilation/diag10862.d-mixin-125(125): Error: assignment cannot be used as a condition, perhaps `==` was meant?
fail_compilation/diag10862.d-mixin-126(126): Error: using the result of a comma expression is not allowed
fail_compilation/diag10862.d-mixin-126(126): Error: assignment cannot be used as a condition, perhaps `==` was meant?
fail_compilation/diag10862.d-mixin-129(129): Error: cannot modify expression `a + b` because it is not an lvalue
fail_compilation/diag10862.d-mixin-130(130): Error: undefined identifier `c`
fail_compilation/diag10862.d(132): Error: undefined identifier `semanticError`
    semanticError;
    ^
fail_compilation/diag10862.d(139): Error: cannot modify lazy variable `bar`
        bar = 2;
        ^
fail_compilation/diag10862.d(141): Error: template instance `diag10862.test3.foo!int` error instantiating
    foo(1 + 1);
       ^
---
*/
void test1()
{
    int a, b;

    if (a = b) {}
    if ((a = b) = 0) {}
    if ((a = b) = (a = b)) {}
    if (a = 0, b = 0) {}        // https://issues.dlang.org/show_bug.cgi?id=15384
    if (auto x = a = b) {}      // this is error, today

    while (a = b) {}
    while ((a = b) = 0) {}
    while ((a = b) = (a = b)) {}
    while (a = 0, b = 0) {}     // https://issues.dlang.org/show_bug.cgi?id=15384

    do {} while (a = b);
    do {} while ((a = b) = 0);
    do {} while ((a = b) = (a = b));
    do {} while (a = 0, b = 0); // https://issues.dlang.org/show_bug.cgi?id=15384

    for (;  a = b; ) {}
    for (;  (a = b) = 0; ) {}
    for (;  (a = b) = (a = b); ) {}
    for (;  a = 0, b = 0; ) {}  // https://issues.dlang.org/show_bug.cgi?id=15384

    semanticError;
}

void test2()
{
    int a, b;

    // (a + b) cannot be an assignment target.
    // However checkAssignAsCondition specilatively rerites it to EqualExp,
    // then the pointless error "is not an lvalue" would not happen.
    if (a + b = a * b) {}

    // The suggestion error masks "undefined identifier" error
    if (a = undefinedIdentifier) {}

    // If the condition is a mixin expression
    if (mixin("a = b")) {}
    if (mixin("(a = b) = 0")) {}
    if (mixin("(a = b) = (a = b)")) {}
    if (mixin("a = 0, b = 0")) {}
    if (auto x = mixin("a = b")) {}     // Note: no error

    if (mixin("a + b = a * b")) {}      // Note: "a + b is not an lvalue"
    if (mixin("a = c")) {}

    semanticError;
}

void test3()
{
    void foo(T)(lazy T bar)
    {
        bar = 2;
    }
    foo(1 + 1);
}
