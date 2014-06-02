module header481;
enum size_t n481 = 3;
enum int[3] sa481 = [1, 2];
struct S481a
{
	int a;
}
struct S481b
{
	this(int n)
	{
	}
}
auto[3] a481_1y = [1, 2, 3];
auto[n481] a481_2y = [1, 2, 3];
auto[$] a481_3y = [1, 2, 3];
int[2][$] a481_4y = [[1, 2], [3, 4], [5, 6]];
int[$][3] a481_5y = [[1, 2], [3, 4], [5, 6]];
auto[$][$] a481_6y = [[1, 2], [3, 4], [5, 6]];
auto[$][$] a481_7y = [sa481[0..2], sa481[1..3]];
S481a[$] a481_8y = [{a:1}, {a:2}];
S481a[][$] a481_9y = [[{a:1}, {a:2}]];
S481a[$][] a481_10y = [[{a:1}, {a:2}]];
S481b[$] a481_11y = [1, 2, 3];
auto[] a481_12y = sa481;
const auto[$] a481_13y = [1, 2, 3];
const auto[][$] a481_14y = [[1], [2], [3]];
const auto[] a481_15y = [1, 2, 3];
const auto[][] a481_16y = [[1, 2, 3]];
auto[$] a481_17y = "abc";
char[$] a481_18y = "abc";
void test481()
{
	auto[3] a1y = [1, 2, 3];
	auto[n481] a2y = [1, 2, 3];
	auto[$] a3y = [1, 2, 3];
	int[2][$] a4y = [[1, 2], [3, 4], [5, 6]];
	int[$][3] a5y = [[1, 2], [3, 4], [5, 6]];
	auto[$][$] a6y = [[1, 2], [3, 4], [5, 6]];
	auto[$][$] a7y = [sa481[0..2], sa481[1..3]];
	S481a[$] a8y = [{a:1}, {a:2}];
	S481a[][$] a9y = [[{a:1}, {a:2}]];
	S481a[$][] a10y = [[{a:1}, {a:2}]];
	S481b[$] a11y = [1, 2, 3];
	auto[] a12y = sa481;
	const auto[$] a13y = [1, 2, 3];
	const auto[][$] a14y = [[1], [2], [3]];
	const auto[] a15y = [1, 2, 3];
	const auto[][] a16y = [[1, 2, 3]];
	int num;
	int* p = &num;
	auto* pp2 = &p;
	const auto* p1y = new int(3);
	const auto*[] a17y = [new int(3)];
	enum E 
	{
		a,
	}
	;
	E[$] esa0 = [];
}
