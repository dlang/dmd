// REQUIRED_ARGS: -O
void main() {}
double foo(double b)
{
    return b / (b == 0) == 0;
}
