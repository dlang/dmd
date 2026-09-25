int factoryArgumentCalls;
int guardCalls;
int actionCalls;
int bindingCopyCalls;

int nextNumber()
{
    factoryArgumentCalls++;
    return 42;
}

bool guardEffect()
{
    guardCalls++;
    return true;
}

int actionEffect()
{
    actionCalls++;
    return 1;
}

struct CopyCounted
{
    this(ref CopyCounted)
    {
        bindingCopyCalls++;
    }
}

enum union Value
{
    case Number(int);
    case Wrapped(CopyCounted);
    case Empty();
}

void main()
{
    switch (Value.Number(nextNumber()))
    {
        case Number(number) => number,
        case Wrapped(payload) => 0,
        case Empty() => 0,
    }
    assert(factoryArgumentCalls == 1);

    switch (Value.Number(1))
    {
        case Number(number) if (guardEffect()) => actionEffect(),
        default => 0,
    }
    assert(guardCalls == 1);
    assert(actionCalls == 1);

    Value wrapped = Value.Wrapped(CopyCounted());
    bindingCopyCalls = 0;
    switch (wrapped)
    {
        case Wrapped(payload) => 0,
        default => 0,
    }
    assert(bindingCopyCalls == 1);
}