int invalidDestructions;
int copyAttempts;

struct ThrowingPayload
{
    bool initialized;

    this(int)
    {
        initialized = true;
    }

    this(ref ThrowingPayload)
    {
        copyAttempts++;
        throw new Exception("copy failed");
    }

    ~this()
    {
        if (!initialized)
            invalidDestructions++;
    }
}

enum union NamedHolder
{
    case Item(ThrowingPayload);
    case Empty();
}

enum union BareHolder
{
    case ThrowingPayload;
    case int;
}

void main()
{
    try
        auto value = NamedHolder.Item(ThrowingPayload(1));
    catch (Exception)
    {
    }
    assert(copyAttempts == 1);
    assert(invalidDestructions == 0);

    ThrowingPayload payload = ThrowingPayload(2);
    try
        BareHolder value = payload;
    catch (Exception)
    {
    }
    assert(copyAttempts == 2);
    assert(invalidDestructions == 0);
}