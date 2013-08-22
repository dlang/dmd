// 10610 CTFE ice

class Bug10610(T)
{
    int baz() immutable {
        return 1;
    }
    static immutable(Bug10610!T) min = new Bug10610!T();
}

void ice10610()
{
   alias T10610 = Bug10610!(int);
   static assert (T10610.min.baz());
}
