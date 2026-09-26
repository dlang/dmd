enum union PointersDirect
{
    case int*;
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

PointersDirect pointers1 = null;

enum union PointersBranch
{
    case int*;
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

PointersBranch pointers2 = PointersBranch(null, true);
