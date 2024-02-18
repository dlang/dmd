module link20802b;

// First test from https://issues.dlang.org/show_bug.cgi?id=20802#c3

enum TransformRes { goOn }

void writeAligned()()
{
    final switch (TransformRes.goOn) { case TransformRes.goOn: break; }
}

struct GcPolicy {}
alias CodepointSet = InversionList!GcPolicy;
struct InversionList(SP=GcPolicy)
{
    this()(uint[] intervals...)
    {
        sanitize();
    }

    void sanitize()
    {
        writeAligned();
    }
}

void decodeGrapheme(Input)(ref Input inp)
{
    final switch (TransformRes.goOn) { case TransformRes.goOn: break; }
}
