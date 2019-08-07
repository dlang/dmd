/* Testing Ownership/Borrowing system
 */

int* malloc();
void free(int*);

/* TEST_OUTPUT:
---
fail_compilation/fob2.d(110): Error: variable `fob2.foo1.b1` no longer has a valid constant copy from `p`
fail_compilation/fob2.d(103): Error: variable `fob2.foo1.p` is left dangling at return
---
*/

#line 100

@live int foo1(int i)
{
    int* p = malloc();
    scope const(int)* b1, b2;
    if (i)
        b1 = p;
    else
        b2 = p;
    *p = 3;
    return *b1;
}

/* TEST_OUTPUT:
---
fail_compilation/fob2.d(203): Error: variable `fob2.zoo2.p` is not Owner, cannot borrow from it
fail_compilation/fob2.d(202): Error: variable `fob2.zoo2.p` is left dangling at return
---
*/

#line 200

@live void zoo2() {
    int* p = malloc();
    foo2(p, p + 1);
}

@live void foo2( scope int* p, scope int* q );

