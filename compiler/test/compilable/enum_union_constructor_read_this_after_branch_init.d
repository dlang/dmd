enum union Pointers
{
    case int*,
    case bool*;

    this(typeof(null) value, bool selectInt)
    {
        if (selectInt)
            this = cast(int*) null;
        else
            this = cast(bool*) null;

        assert(switch (this)
        {
            case int* => true,
            case bool* => true,
        });
    }
}

Pointers pointers = Pointers(null, true);