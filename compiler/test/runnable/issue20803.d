// REQUIRED_ARGS: -inline

struct V
{
    bool alive = true;
    void checkAlive() { assert(alive); }
}

struct S
{
    V v;
    @disable this(this);
    ~this() { v.alive = false; }
}

void main()
{
    S().v.checkAlive();
}
