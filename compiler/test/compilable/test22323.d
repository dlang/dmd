// REQUIRED_ARGS: -preview=dip1000

struct Schema
{
    int[int] tables;
}
struct S(Schema s)
{
    void g() { cast(void)s.tables; }
}
auto makeSchema() => Schema([0: 0]);
alias Row = S!(makeSchema());
