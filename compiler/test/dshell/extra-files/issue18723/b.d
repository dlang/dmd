module b;
import a;
import c;

void main()
{
    assert(twice(3) == 6);
    assert(triple(3) == 9);
    version (LocalCall)
        assert(fromA() == 8);
}
