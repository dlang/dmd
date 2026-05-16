/* TEST_OUTPUT:
---
fail_compilation/type_as_initializer.d(40): Error: initializer must be an expression, not `S1`
fail_compilation/type_as_initializer.d(40):        perhaps use `S1()` to construct a value of the type
fail_compilation/type_as_initializer.d(43): Error: initializer must be an expression, not `S2`
fail_compilation/type_as_initializer.d(46): Error: initializer must be an expression, not `S3`
fail_compilation/type_as_initializer.d(46):        perhaps use `S3(...)` to construct a value of the type
fail_compilation/type_as_initializer.d(49): Error: initializer must be an expression, not `C1`
fail_compilation/type_as_initializer.d(49):        perhaps use `new C1()` to construct a value of the type
fail_compilation/type_as_initializer.d(52): Error: initializer must be an expression, not `C2`
fail_compilation/type_as_initializer.d(52):        perhaps use `new C2(...)` to construct a value of the type
---
*/

// Struct with no constructors - hint with ()
struct S1 {}

// Struct with copy constructor - no hint (can't default construct)
struct S2
{
    this(ref S2) {}
}

// Struct with required-arg constructor only - hint with (...)
struct S3
{
    this(int x) {}
}

// Class with no constructors - hint with new ()
class C1 {}

// Class with required-arg constructor only - hint with new (...)
class C2
{
    this(int x) {}
}

// Test cases
enum e1 = S1;  // line 44

// Copy constructor - no hint
enum e2 = S2;  // line 47

// Required args - hint with (...)
enum e3 = S3;  // line 50

// Class with no ctor - hint with new ()
enum e4 = C1;  // line 53

// Class with required args - hint with new (...)
enum e5 = C2;  // line 56
