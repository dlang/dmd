
class C {}

void main()
{
    immutable c = new immutable(C);
    delete c;
}
