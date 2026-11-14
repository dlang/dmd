
struct S { uint f : 19; }
S s;

int main()
{
    s.f = 10;
    assert(s.f - 20 < 0); // fails
    return 0;
}
