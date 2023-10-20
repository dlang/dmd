/* https://issues.dlang.org/show_bug.cgi?id=23044
 */

void other(int x){}
void fn()
{
	int x;
	other(x), x = 1;
}
