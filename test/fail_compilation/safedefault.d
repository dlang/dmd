/* REQUIRED_ARGS: -preview=safedefault
 */

#line 50
         void default_();
@system  void system();
@trusted void trusted();
@safe    void safe();

/*********************
 * TEST_OUTPUT:
---
fail_compilation/safedefault.d(103): Error: `@safe` function `safedefault.test1` cannot call `@system` function `safedefault.system`
fail_compilation/safedefault.d(51):        `safedefault.system` is declared here
---
*/

#line 100

void test1()
{
    system();
}

/**********************/

void func2()()
{
    system();
}

/**********************/

void func3()()
{
    func3();
}

/**********************/

void func4()()
{
    func5();
}

void func5()()
{
    func4();
}

/**********************/

#line 600

void test6(bool b)
{
    @safe    void function() fp1 = b ? &default_ : &default_;
    @system  void function() fp2 = b ? &default_ : &system;
    @trusted void function() fp3 = b ? &default_ : &trusted;
    @safe    void function() fp4 = b ? &default_ : &safe;

    @system  void function() fp5 = b ? &system : &system;
    @system  void function() fp6 = b ? &system : &trusted;
    @system  void function() fp7 = b ? &system : &safe;

    @trusted void function() fp8 = b ? &trusted : &trusted;
    @trusted void function() fp9 = b ? &trusted : &safe;

    @safe    void function() fp10 = b ? &safe : &safe;
}

/**********************/
/* TEST_OUTPUT:
---
fail_compilation/safedefault.d(703): Error: cannot implicitly convert expression `b ? & default_ : & system` of type `void function() @system` to `void function() @safe`
fail_compilation/safedefault.d(706): Error: cannot implicitly convert expression `b ? & system : & system` of type `void function() @system` to `void function() @safe`
fail_compilation/safedefault.d(707): Error: cannot implicitly convert expression `b ? & system : & trusted` of type `void function() @system` to `void function() @safe`
fail_compilation/safedefault.d(708): Error: cannot implicitly convert expression `b ? & system : & safe` of type `void function() @system` to `void function() @safe`
---
*/

#line 700

void test7(bool b)
{
    @safe void function() fp2 = b ? &default_ : &system;
    @safe void function() fp3 = b ? &default_ : &trusted;

    @safe void function() fp5 = b ? &system : &system;
    @safe void function() fp6 = b ? &system : &trusted;
    @safe void function() fp7 = b ? &system : &safe;

    @safe void function() fp8 = b ? &trusted : &trusted;
    @safe void function() fp9 = b ? &trusted : &safe;
}

/******************************/

void test8(void delegate() dg)
{
    dg();
}

