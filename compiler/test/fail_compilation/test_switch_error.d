/++
https://issues.dlang.org/show_bug.cgi?id=22514
TEST_OUTPUT:
---
fail_compilation/test_switch_error.d(64): Error: undefined identifier `doesNotExist`
    switch (doesNotExist)
            ^
fail_compilation/test_switch_error.d(67): Error: undefined identifier `alsoDoesNotExits`
            alsoDoesNotExits();
            ^
fail_compilation/test_switch_error.d(70): Error: duplicate `case 2` in `switch` statement
        case 2: break;
        ^
fail_compilation/test_switch_error.d(80): Error: undefined identifier `doesNotExist`
    switch (doesNotExist)
            ^
fail_compilation/test_switch_error.d(93): Error: undefined identifier `a`
        case a: break;
             ^
fail_compilation/test_switch_error.d(94): Error: undefined identifier `b`
        case b: break;
             ^
fail_compilation/test_switch_error.d(102): Error: undefined identifier `doesNotExits`
    auto foo = doesNotExits();
               ^
fail_compilation/test_switch_error.d(116): Error: `case` variables have to be `const` or `immutable`
        case i: break;
        ^
fail_compilation/test_switch_error.d(123): Error: `case` variables not allowed in `final switch` statements
        case j: break;
        ^
fail_compilation/test_switch_error.d(142): Error: undefined identifier `undefinedFunc`
   final switch(undefinedFunc())
                ^
fail_compilation/test_switch_error.d(146): Error: `case` expression must be a compile-time `string` or an integral constant, not `Strukt(1)`
      case Strukt(1):   break;
      ^
fail_compilation/test_switch_error.d(147): Error: `case` variables have to be `const` or `immutable`
      case param:       break;
      ^
fail_compilation/test_switch_error.d(147): Error: `case` variables not allowed in `final switch` statements
      case param:       break;
      ^
fail_compilation/test_switch_error.d(148): Error: `case` variables not allowed in `final switch` statements
      case constant:    break;
      ^
fail_compilation/test_switch_error.d(151): Error: undefined identifier `undefinedFunc2`
   switch (undefinedFunc2())
           ^
fail_compilation/test_switch_error.d(180): Error: undefined identifier `undefinedFunc`
    final switch(undefinedFunc())
                 ^
fail_compilation/test_switch_error.d(182): Error: `case` expression must be a compile-time `string` or an integral constant, not `SubtypeOfInt(2)`
        case SubtypeOfInt(2):         break;
        ^
fail_compilation/test_switch_error.d(183): Error: `case` expression must be a compile-time `string` or an integral constant, not `SubtypeOfIntMethod()`
        case SubtypeOfIntMethod():    break;
        ^
---
++/

void test1()
{
    switch (doesNotExist)
    {
        case 1:
            alsoDoesNotExits();
            break;
        case 2: break;
        case 2: break;
    }
}

// Line 100 starts here

enum foo = 1;

void test2()
{
    switch (doesNotExist)
    {
        case foo: break;
    }
}

// Line 200 starts here

void test3()
{

    switch (1)
    {
        case a: break;
        case b: break;
    }
}

// Line 300 starts here

void test4()
{
    auto foo = doesNotExits();
    switch (1)
    {
        case foo: break;
        case foo: break;
    }
}

// Line 400 starts here

void test5(int i)
{
    switch (i)
    {
        case i: break;
        default: break;
    }

    const int j = i;
    final switch (i)
    {
        case j: break;

    }
}

// Line 500 starts here

enum Foo
{
   one, two
}

struct Strukt
{
    int i;
}

void errorsWithErrors(int param, immutable int constant)
{
   final switch(undefinedFunc())
   {
      case Foo.one:     break;
      case Foo.two:     break;
      case Strukt(1):   break;
      case param:       break;
      case constant:    break;
   }

   switch (undefinedFunc2())
   {
       case constant:   break;
   }
}

// Line 600 starts here

struct SubtypeOfInt
{
    int i;
    alias i this;
}

struct SubtypeOfIntMethod
{
    int getI() { return 0; }
    alias getI this;
}

void errorsWithErrors2(int param)
{
    final switch(param)
    {
        case SubtypeOfInt(1):         break;
        case SubtypeOfIntMethod():    break;
    }

    // This snippet causes somewhat misleading error messages
    final switch(undefinedFunc())
    {
        case SubtypeOfInt(2):         break;
        case SubtypeOfIntMethod():    break;
    }
}
