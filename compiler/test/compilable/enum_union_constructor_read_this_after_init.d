enum union Pointers
{
    case int*,
    case bool*;

    this(typeof(null) value)
    {
        this = cast(int*) null;
        assert(switch (this)
        {
            case int* => true,
            case bool* => false,
        });
    }
}

Pointers pointers = null;