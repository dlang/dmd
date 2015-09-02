import core.runtime;

void main(string[] args)
{
    profilegc_setlogfilename(args[1]);
    auto p = new uint;
}
