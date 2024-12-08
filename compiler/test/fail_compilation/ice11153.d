/*
TEST_OUTPUT:
---
fail_compilation/ice11153.d(15): Error: function declaration without return type. (Note that constructors are always named `this`)
    foo(T)() {}
       ^
fail_compilation/ice11153.d(15): Error: no identifier for declarator `foo()`
    foo(T)() {}
             ^
---
*/

struct S
{
    foo(T)() {}
    // Parser creates a TemplateDeclaration object with ident == NULL
}

void main() {}
