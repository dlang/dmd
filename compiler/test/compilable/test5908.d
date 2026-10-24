/*
REQUIRED_ARGS: -O
*/

// This bug is no longer caught by the dmd optimizer - other backends might catch it or give a different message

int main()
{
    int a = 1;
    int b = 0;
    return (a % b) +
        (a / b);
}
