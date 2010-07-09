
alias char[]  strtype;
alias char[64] strtype;
alias char[128] strtype;
alias char[256] strtype;

int main()
{
    printf("%u", strtype.sizeof);
    return 0;
}
