import lib846;

void main()
{
    auto num = removeIf("abcdef".dup, (char c){ return c == 'c'; });
}
