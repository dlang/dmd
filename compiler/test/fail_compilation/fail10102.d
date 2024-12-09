/*
TEST_OUTPUT:
---
fail_compilation/fail10102.d(56): Error: variable `fail10102.main.m` - default construction is disabled for type `NotNull!(int*)`
    NotNull!(int*) m;               // should fail
                   ^
fail_compilation/fail10102.d(57): Error: variable `fail10102.main.a` - default construction is disabled for type `NotNull!(int*)[3]`
    NotNull!(int*)[3] a;            // should fail
                      ^
fail_compilation/fail10102.d(58): Error: default construction is disabled for type `NotNull!(int*)`
    auto b = new NotNull!(int*)[3]; // should fail
             ^
fail_compilation/fail10102.d(59): Error: field `S.m` must be initialized because it has no default constructor
    S s = S();                      // should fail
           ^
---
*/

struct NotNull(T)
{
    T p;

    alias p this;

    this(T p)
    {
        assert(p != null, "pointer is null");
        this.p = p;
    }

    @disable this();

    NotNull opAssign(T p)
    {
        assert(p != null, "assigning null to NotNull");
        this.p = p;
        return this;
    }
}

void main()
{
    struct S
    {
        NotNull!(int *) m;
        // should fail: an explicit constructor must be required for S
    }

    int i;
    NotNull!(int*) n = &i;
    *n = 3;
    assert(i == 3);
    n = &i;
    n += 1;

    NotNull!(int*) m;               // should fail
    NotNull!(int*)[3] a;            // should fail
    auto b = new NotNull!(int*)[3]; // should fail
    S s = S();                      // should fail
}
