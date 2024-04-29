enum A { B }
static assert(is(typeof(A.B) == A));
static assert(is(typeof(A(A.B)) == A));

void main()
{
    Exception ex;
    auto o = Object(ex);
    static assert(is(typeof(o) == Object));
}
