import imports.test35a;

void main()
{
    auto num = removeIf( "abcdef".dup, ( char c ) { return c == 'c'; } );
}

