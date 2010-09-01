extern(C) int printf(const char*, ...);

void main(string[] args)
{
    args = args[1..$];
    long combinations = 1 << args.length;
    for (size_t i = 0; i < combinations; i++)
    {
        bool printed = false;

        //printf("\"");
        for (size_t j = 0; j < args.length; j++)
        {
            if (i & 1 << j)
            {
                if (printed)
                    printf(" ");
                printf("%.*s", args[j].length, args[j].ptr);
                printed = true;
            }
        }
        //printf("\"\n");
        printf("\n");
    }
}
