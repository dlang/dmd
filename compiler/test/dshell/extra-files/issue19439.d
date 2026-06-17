module issue19439;
import issue19439b;

void main()
{
    auto b = new B();
    assert(b.obj !is null);
}
