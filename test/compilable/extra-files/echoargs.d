import core.stdc.stdio;
int main(string[] args)
{
    string prefix = "";
    foreach(arg; args[1 .. $])
    {
        printf("%s%.*s", prefix.ptr, arg.length, arg.ptr);
        prefix = " ";
    }
    printf("\n");
    return 0;
}
