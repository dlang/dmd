// see also: bug 8

import imports.bug846b;

shared static this()
{
    auto num = removeIf( "abcdef".dup, ( char c ) { return c == 'c'; } );
    assert(num == 5);
}
