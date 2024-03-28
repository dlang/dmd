/* Implicit Conversion of Template Instantiations
 */
/* TEST_OUTPUT:
---
fail_compilation/imptmpcnv.d(31): Error: cannot implicitly convert expression `a` of type `S2!(const(int))` to `const(S2!int)`
fail_compilation/imptmpcnv.d(48): Error: cannot implicitly convert expression `a` of type `S3!(const(int))` to `const(S3!int)`
fail_compilation/imptmpcnv.d(62): Error: cannot implicitly convert expression `a` of type `S4!(const(int))` to `const(S4!int)`
fail_compilation/imptmpcnv.d(76): Error: cannot implicitly convert expression `a` of type `S5!(const(int))` to `const(S5!int)`
---
*/


/*************************/

struct S1(T) { T t; }

void foo1()
{
    S1!(const int) a;
    const(S1!int) b = a;
    S1!(const int) c = b;
}

/*************************/

struct S2(T) { T* t; }

void foo2()
{
    S2!(const int) a;
    const(S2!int) b = a;
}

/*************************/

struct S3(T)
{
    static if (is(T == const))
    {
	int x;
    }
    T t;
}

void foo3()
{
    S3!(const int) a;
    const(S3!int) b = a;
}

/*************************/

struct S4(T)
{
    static if (is(T == const)) { int x; } else { long x; }
    T t;
}

void foo4()
{
    S4!(const int) a;
    const(S4!int) b = a;
}

/*************************/

struct S5(T)
{
    T t;
    static if (is(T == const)) { int x; } else { long x; }
}

void foo5()
{
    S5!(const int) a;
    const(S5!int) b = a;
}
