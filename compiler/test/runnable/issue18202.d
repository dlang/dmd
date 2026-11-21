// https://github.com/dlang/dmd/issues/18202

void main()
{
    string s = "hello";
    immutable(char)* p = "hello".ptr;
    assert(s.ptr == p);

    // pooled literals keep a terminator of their own code unit size
    immutable(char)*  ec = "".ptr;
    immutable(wchar)* ew = ""w.ptr;
    immutable(dchar)* ed = ""d.ptr;
    assert(ec[0] == 0);
    assert(ew[0] == 0);
    assert(ed[0] == 0);

    // a reinterpret cast gives the literal a code unit size wider than a
    // dchar, so the pool must key on any size, not just 1/2/4
    auto w8 = cast(long[1])"abcdefgh"c;
    assert(w8[0] == 0x6867_6665_6463_6261);
}
