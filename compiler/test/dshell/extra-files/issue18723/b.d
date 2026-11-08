module b;
import a;

void main()
{
    assert(twice(3) == 6);
    version (LocalCall)
        assert(fromA() == 8);
}
