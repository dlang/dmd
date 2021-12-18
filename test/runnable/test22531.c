// https://issues.dlang.org/show_bug.cgi?id=22531

int main()
{
    void fn(void);
    fn();
    return 0;
}

void fn(void)
{
}

