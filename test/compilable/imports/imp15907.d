module imports.imp15907;

void process(T)(T t)
{
    foreach (member; __traits(allMembers, T))
    {
        __traits(getMember, t, member) = __traits(getMember, t, member).init;
    }
}

enum allMembers(T) = [__traits(allMembers, T)];
