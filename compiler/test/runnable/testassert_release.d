/*
https://issues.dlang.org/show_bug.cgi?id=21779

PERMUTE_ARGS: -checkaction=context
ARG_SETS: -release
ARG_SETS: -check=assert=off
*/

int boo()
{
	assert(false);
}

extern(C) int main()
{
	assert(boo());
	return 0;
}
