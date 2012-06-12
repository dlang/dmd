// REQUIRED_ARGS: -w

/******************************************/
// 6652

void main()
{
    size_t[] res;
    foreach (i; 0..2)
    {
        res ~= ++i;
    }
}
