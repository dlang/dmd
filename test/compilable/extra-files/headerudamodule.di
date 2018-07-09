@(1, UDA(2))
module testheaderudamodule;
struct UDA
{
	int a;
}
void main();
void foo(@(1) int bar, @UDA(2) string bebe);
