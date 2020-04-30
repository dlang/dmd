// REQUIRED_ARGS:
// PERMUTE_ARGS:

void main()
{
    auto a = 12345;
    auto b = 54321;

    auto c = (!a) & b;
    auto d = !(a & b);
    auto e = (!a) | b;
    auto f = !(a | b);
}
