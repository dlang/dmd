import imports.link846a;

void main()
{
    auto num = removeIf("abcdef".dup, (char c){ return c == 'c'; });
}
