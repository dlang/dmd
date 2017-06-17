class Foo
{
    auto foo()
    out {}
    body {}

    auto bar()
    out { assert (__result > 5); }
    body { return 6; }

    auto bar_2()
    out (res) { assert (res > 5); }
    body { return 6; }

    int concrete()
    out { assert(__result > 5); }
    body { return 6; }

    int concrete_2()
    out(res) { assert (res > 5); }
    body { return 6; }

    void void_foo()
    out {}
    body {}

    auto void_auto()
    out {}
    body {}
}
