/*
TEST_OUTPUT:
---
fail_compilation/funcpostattr.d(21): Error: `deprecated` token is not allowed in postfix position
void foo() deprecated extern;
           ^
fail_compilation/funcpostattr.d(21): Error: `extern` token is not allowed in postfix position
void foo() deprecated extern;
                      ^
fail_compilation/funcpostattr.d(25): Error: `static` token is not allowed in postfix position
    int foo() static ref => i;
              ^
fail_compilation/funcpostattr.d(25): Error: `ref` token is not allowed in postfix position
    int foo() static ref => i;
                     ^
fail_compilation/funcpostattr.d(30): Error: `override` token is not allowed in postfix position
    void foo() override {}
               ^
---
*/
void foo() deprecated extern;

void main() {
    int i;
    int foo() static ref => i;
}

class C
{
    void foo() override {}
}
