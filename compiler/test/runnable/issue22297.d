// REQUIRED_ARGS: -inline

int[4] arr;

int[4] f() => arr;

void main()
{
    f().ptr[1] = 1;
    assert(arr[1] == 0);
}
