import core.memory;

extern(C) __gshared string[] rt_options = [ "gcopt=gc:unknowngc" ];

void main()
{
    // GC initialized upon first call -> Unknown GC error is thrown
    GC.enable();
}
