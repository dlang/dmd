
void main()
{
    goto label;
label:
}

/***************************************************/
// 12460

void f12460(T)()
{
    static if (is(T == int))
    {
        goto end;
    }
end:
}

void test12460()
{
    f12460!int();
}
