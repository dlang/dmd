enum A { a }
enum B { b }
struct T { A x; B y; }
void main()
{
    T t;
    auto r1 = [cast(int)(t.x), cast(int)(t.y)]; // OK
    auto r3 = [t.x, t.y]; // crash
    static assert(is(typeof(r3[0]) == int));
}
