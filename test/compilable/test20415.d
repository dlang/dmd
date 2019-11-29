// https://issues.dlang.org/show_bug.cgi?id=20415
// REQUIRED_ARGS: -c -O

void t()
{
    auto a = false ? B().p : null;
}

struct B
{
    void* p;
    ~this() {}
}

