/*
TEST_OUTPUT:
---
fail_compilation/test4838.d(25): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
void function() const fpc;
                      ^
fail_compilation/test4838.d(26): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
void function() immutable fpi;
                          ^
fail_compilation/test4838.d(27): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
void function() shared fps;
                       ^
fail_compilation/test4838.d(28): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
void function() shared const fpsc;
                             ^
fail_compilation/test4838.d(29): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
void function() inout fpw;
                      ^
fail_compilation/test4838.d(30): Error: `const`/`immutable`/`shared`/`inout`/`return` attributes are only valid for non-static member functions
void function() shared inout fpsw;
                             ^
---
*/

void function() const fpc;
void function() immutable fpi;
void function() shared fps;
void function() shared const fpsc;
void function() inout fpw;
void function() shared inout fpsw;
