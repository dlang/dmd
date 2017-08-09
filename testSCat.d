string fn()
{
    char[] s;
    s.length = cast(uint)('z'-'a');
    foreach(i; 0 ..cast(uint) s.length) { s[i] = cast(char)(i+'a'); }
    return cast(string)s;
}

pragma(msg, 'z'-'a');
pragma(msg, fn());
