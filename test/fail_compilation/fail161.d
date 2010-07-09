template MetaString(String)
{
    alias String Value;
}

void main()
{
    alias MetaString!("2 == 1") S;
    assert(mixin(S.Value));
}

