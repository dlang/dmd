// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

template isGood(T)
{
    enum isGood = true;
}
void main()
{
    string foo(R)(R data) if (isGood!R)
    {
        return "";
    }
    foo(1);
}
