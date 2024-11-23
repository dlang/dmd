/*
TEST_OUTPUT:
---
fail_compilation/enum9921.d(15): Error: enum `enum9921.X` base type must not be `void`
enum X : void;
^
fail_compilation/enum9921.d(17): Error: enum `enum9921.Z` base type must not be `void`
enum Z : void { Y };
^
fail_compilation/enum9921.d(19): Error: variable `enum9921.x` - manifest constants must have initializers
enum int x;
         ^
---
*/
enum X : void;

enum Z : void { Y };

enum int x;
