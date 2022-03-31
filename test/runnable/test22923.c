/* REQUIRED_ARGS: -fPIC
 * DISABLED: win32 win64
 */

// https://issues.dlang.org/show_bug.cgi?id=22923

static int xs;
int printf(char *, ...);
int main()
{
	printf("%p\n", &xs); // prints 0x1
	int x = xs; // segfaults
	return 0;
}
static int xs = 1;
