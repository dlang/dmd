module header481;
enum size_t n481 = 3;
enum int[3] sa481 = [1, 2];
struct S481a
{
	int a;
}
struct S481b
{
	this(int n);
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
const[$] a481_13y = [1, 2, 3];
const[][$] a481_14y = [[1], [2], [3]];
const[] a481_15y = [1, 2, 3];
const[][] a481_16y = [[1, 2, 3]];
auto[$] a481_17y = "abc";
char[$] a481_18y = "abc";
void test481();
void test481b();
