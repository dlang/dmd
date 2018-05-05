import test17968a;

void main()
{
    auto r = fun2.fun1;
    // just check that getHash works (doesn't throw).
    typeid(r).getHash(&r);

    // try gethash when member is null.
    r.t = null;
    typeid(r).getHash(&r);
}
