// REQUIRED_ARGS: -wi

// https://issues.dlang.org/show_bug.cgi?id=22930

int printf(const char *, ...);
void exit(int);

int main()
{
    switch (1)
    {
	case 2:
	    printf("failed test 22930\n");
	    exit(1);
    }
    return 0;
}
