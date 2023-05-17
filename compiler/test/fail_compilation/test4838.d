/*
TEST_OUTPUT:
---
fail_compilation/test4838.d(15): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
fail_compilation/test4838.d(16): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
fail_compilation/test4838.d(17): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
fail_compilation/test4838.d(18): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
fail_compilation/test4838.d(19): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
fail_compilation/test4838.d(20): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
fail_compilation/test4838.d(22): Error: `const`/`immutable`/`shared`/`inout`/`scope`/`return` attributes are only valid for non-static member functions
fail_compilation/test4838.d(24): Error: `const`/`immutable`/`shared`/`inout`/`scope`/`return` attributes are only valid for non-static member functions
---
*/

void function() const fpc;
void function() immutable fpi;
void function() shared fps;
void function() shared const fpsc;
void function() inout fpw;
void function() shared inout fpsw;

function void() scope lfps;
void f(){
    function void() return lfpr;
}
