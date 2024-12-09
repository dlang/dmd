/*
TEST_OUTPUT:
---
fail_compilation/parse12924.d(28): Error: declaration expected following attribute, not `;`
static;         void f1() {}
      ^
fail_compilation/parse12924.d(29): Error: declaration expected following attribute, not `;`
deprecated;     void f2() {}
          ^
fail_compilation/parse12924.d(30): Error: declaration expected following attribute, not `;`
deprecated(""); void f3() {}
              ^
fail_compilation/parse12924.d(31): Error: declaration expected following attribute, not `;`
extern(C);      void f4() {}
         ^
fail_compilation/parse12924.d(32): Error: declaration expected following attribute, not `;`
public;         void f5() {}
      ^
fail_compilation/parse12924.d(33): Error: declaration expected following attribute, not `;`
align(1);       void f6() {}
        ^
fail_compilation/parse12924.d(34): Error: declaration expected following attribute, not `;`
@(1);           void f7() {}
    ^
---
*/

static;         void f1() {}
deprecated;     void f2() {}
deprecated(""); void f3() {}
extern(C);      void f4() {}
public;         void f5() {}
align(1);       void f6() {}
@(1);           void f7() {}
