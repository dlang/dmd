// REQUIRED_ARGS: -w -Wno-braces -Wno-not-reachable
// PERMUTE_ARGS:

void main()
{
    ;

    if(true)
    if(true) {}
    else {}

    return;
    return;
}
