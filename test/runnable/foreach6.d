void main()
{
    int i;

    foreach (c; "abcd")
    {
        static assert(is(typeof(c) == dchar));
        switch (i++)
        {   case 0:     assert(c == 'a');   break;
            case 1:     assert(c == 'b');   break;
            case 2:     assert(c == 'c');   break;
            case 3:     assert(c == 'd');   break;
            default:    assert(0);
        }
    }

    i = 0;
    foreach (ref c; "abcd".dup)
    {
        static assert(is(typeof(c) == char));
        switch (i++)
        {   case 0:     assert(c == 'a');   break;
            case 1:     assert(c == 'b');   break;
            case 2:     assert(c == 'c');   break;
            case 3:     assert(c == 'd');   break;
            default:    assert(0);
        }
    }

    i = 0;
    foreach (c; "世界你好")
    {
        static assert(is(typeof(c) == dchar));
        switch (i++)
        {   case 0:     assert(c == '世');   break;
            case 1:     assert(c == '界');   break;
            case 2:     assert(c == '你');   break;
            case 3:     assert(c == '好');   break;
            default:    assert(0);
        }
    }
}
