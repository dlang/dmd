module enum_union_header_hardening;

struct Marker
{
    string name;
}

template AliasSeq(T...)
{
    alias AliasSeq = T;
}

enum union Value
{
    @Marker("none") case None();
    @Marker("some") case Some(int);
}

int inspect(T)(Value value)
{
    return switch (value)
    {
        static foreach (index; AliasSeq!(0, 1))
        {
            static if (index == 0)
                case None() => 0,
            else
                case Some(payload) => payload,
        }
    };
}