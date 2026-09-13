class C1 {}
class C2 : C1 {}

enum union Pointers
{
    case First = C1,
    case Second = C2,
}

string classify(Pointers value)
{
    return switch (value)
    {
        case C1 => "C1",
        case C2 => "C2",
    };
}

void main()
{
    assert(classify(Pointers(new C1)) == "C1");
    assert(classify(Pointers(new C2)) == "C2");
    Pointers.First first = new C1;
    Pointers.Second second = new C2;
    assert(classify(Pointers.First(first)) == "C1");
    assert(classify(Pointers.Second(second)) == "C2");
}