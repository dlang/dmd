/*
TEST_OUTPUT:
---
fail_compilation/diag15713.d(30): Error: no property `widthSign` for `this` of type `diag15713.WrData.Data`
            __traits(getMember, this, name ~ "Sign");
            ^
fail_compilation/diag15713.d(26):        struct `Data` defined here
    struct Data
    ^
fail_compilation/diag15713.d(50): Error: template instance `diag15713.conwritefImpl!("parse-int", "width", "\n", Data(null))` error instantiating
    enum conwritefImpl = conwritefImpl!("parse-int", "width", fmt, data);
                         ^
fail_compilation/diag15713.d(55):        instantiated from here: `conwritefImpl!("main", "\n", Data(null))`
    conwritefImpl!("main", "\n", WrData(0, 0));
    ^
fail_compilation/diag15713.d(60):        instantiated from here: `fdwritef!()`
    fdwritef();
            ^
---
*/

void wrWriteWidthChar() {}

auto WrData(int , int )
{
    struct Data
    {
        auto initInt(string name)()
        {
            __traits(getMember, this, name ~ "Sign");
        }
    }
    return Data();
}

template conwritefImpl(string state, string field, string fmt, alias data, AA...)
if (state == "parse-int")
{
    enum conwritefImpl = data.initInt!field;
}

template baz(string state, string fmt, alias data, AA...) {}
template bar(string state, string fmt, alias data, AA...) {}

    enum a = "parse-format";

template conwritefImpl(string state, string fmt, alias data, AA...)
if (state == "main")
{
    enum conwritefImpl = conwritefImpl!("parse-int", "width", fmt, data);
}

void fdwritef()()
{
    conwritefImpl!("main", "\n", WrData(0, 0));
}

void conwriteln()
{
    fdwritef();
}
