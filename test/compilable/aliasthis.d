void nonMatchingAliasThisVsUnsafeUpcast()
{
    static class B {}
    static class S : B
    {
        @property int at() const {assert(false);}
        alias at this;
    }
    const S c;
    auto b = cast(B) c;
}
