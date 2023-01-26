
template Temp(T, S)
{
    enum Temp = T.stringof ~ " " ~ S.stringof;
}

// static assert(Temp!(S: int, T: string, double) == "string int"); TODO
