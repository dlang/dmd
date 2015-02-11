private
{
    void privF() {}
    class privC {}
    struct privS {}
    union privU {}
    interface privI {}
    enum privE { foo }
    mixin template privMT() {}

    void privTF(T)() {}
    class privTC(T) {}
    struct privTS(T) {}
    union privTU(T) {}
    interface privTI(T) {}
}

void publF(T)() {}
void publFA(alias A)() {}
private alias privC privA;

public mixin template publMT() {}
