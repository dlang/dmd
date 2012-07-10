// REQUIRED_ARGS: -w

/******************************************/
// 6652

void main()
{
    size_t[] res;
    foreach (i, e; [1,2,3,4,5])
    {
        res ~= ++i;
    }
}
