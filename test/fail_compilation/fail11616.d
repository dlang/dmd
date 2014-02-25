/*
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail11616.d(22): Error: function fail11616.D.a cannot override final function fail11616.C.a
fail_compilation/fail11616.d(22): Error: function fail11616.D.a does not override any function
fail_compilation/fail11616.d(23): Error: function fail11616.D.b cannot override final function fail11616.C.b
fail_compilation/fail11616.d(24): Error: function fail11616.D.c static member functions cannot be virtual
fail_compilation/fail11616.d(29): Error: function fail11616.S.x struct member functions cannot be virtual
---
*/

class C
{
virtual:
    final void a();
    final void b();
}

class D : C
{
    override void a() {}
    void b() {}
    static virtual void c();
}

struct S
{
    virtual void x() {}
}
