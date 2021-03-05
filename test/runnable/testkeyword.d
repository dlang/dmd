// PERMUTE_ARGS:
// EXTRA_SOURCES: imports/testkwd_file.d
module testkeyword;
import imports.testkwd;

/****************************************/
// calee test

static assert(getCalleeFile()  == thatFile);
static assert(getCalleeLine()  == thatLine);
static assert(getCalleeMod()   == thatMod);
static assert(getCalleeFunc()  == thatFunc);
static assert(getCalleeFunc2() == thatFunc2);
static assert(getCalleeFunc3() == thatFunc3);

void testCallee()
{
    static assert(getCalleeFile()  == thatFile);
    static assert(getCalleeLine()  == thatLine);
    static assert(getCalleeMod()   == thatMod);
    static assert(getCalleeFunc()  == thatFunc);
    static assert(getCalleeFunc2() == thatFunc2);
    static assert(getCalleeFunc3() == thatFunc3);
}

/****************************************/
// caller test

version(Windows) enum sep = "\\";  else enum sep = "/";

enum thisFile = "runnable"~sep~"testkeyword.d";
enum thisMod  = "testkeyword";

static assert(getFuncArgFile()  == thisFile);
static assert(getFuncArgLine()  == 35);
static assert(getFuncArgMod()   == thisMod);
static assert(getFuncArgFunc()  == "");
static assert(getFuncArgFunc2() == "");
static assert(getFuncArgFunc3() == "");

static assert(getFuncTiargFile()  == thisFile);
static assert(getFuncTiargLine()  == 42);
static assert(getFuncTiargMod()   == thisMod);
static assert(getFuncTiargFunc()  == "");
static assert(getFuncTiargFunc2() == "");
static assert(getFuncTiargFunc3() == "");

static assert(getInstTiargFile!()  == thisFile);
static assert(getInstTiargLine!()  == 49);
static assert(getInstTiargMod!()   == thisMod);
static assert(getInstTiargFunc!()  == "");
static assert(getInstTiargFunc2!() == "");
static assert(getInstTiargFunc3!() == "");

void main(string[] args) nothrow
{
    enum thisFunc       = "testkeyword.main";
    enum thisFunc2 = "void testkeyword.main(string[] args) nothrow";
    enum thisFunc3 = "_Dmain";

    static assert(getFuncArgFile()  == thisFile);
    static assert(getFuncArgLine()  == 62);
    static assert(getFuncArgMod()   == thisMod);
    static assert(getFuncArgFunc()  == thisFunc);
    static assert(getFuncArgFunc2() == thisFunc2);
    static assert(getFuncArgFunc3() == thisFunc3);

    static assert(getFuncTiargFile()  == thisFile);
    static assert(getFuncTiargLine()  == 69);
    static assert(getFuncTiargMod()   == thisMod);
    static assert(getFuncTiargFunc()  == thisFunc);
    static assert(getFuncTiargFunc2() == thisFunc2);
    static assert(getFuncTiargFunc3() == thisFunc3);

    static assert(getInstTiargFile!()  == thisFile);
    static assert(getInstTiargLine!()  == 76);
    static assert(getInstTiargMod!()   == thisMod);
    static assert(getInstTiargFunc!()  == thisFunc);
    static assert(getInstTiargFunc2!() == thisFunc2);
    static assert(getInstTiargFunc3!() == thisFunc3);

    void nested(int x, float y) nothrow
    {
        enum thisFunc       = "testkeyword.main.nested";
        enum thisFunc2 = "void testkeyword.main.nested(int x, float y) nothrow";
        enum thisFunc3 = "_D11testkeyword4mainFNbAAyaZ6nestedMFNbifZv";

        static assert(getFuncArgFile()  == thisFile);
        static assert(getFuncArgLine()  == 89);
        static assert(getFuncArgMod()   == thisMod);
        static assert(getFuncArgFunc()  == thisFunc);
        static assert(getFuncArgFunc2() == thisFunc2);
        static assert(getFuncArgFunc3() == thisFunc3);

        static assert(getFuncTiargFile()  == thisFile);
        static assert(getFuncTiargLine()  == 96);
        static assert(getFuncTiargMod()   == thisMod);
        static assert(getFuncTiargFunc()  == thisFunc);
        static assert(getFuncTiargFunc2() == thisFunc2);
        static assert(getFuncTiargFunc3() == thisFunc3);

        static assert(getInstTiargFile!()  == thisFile);
        static assert(getInstTiargLine!()  == 103);
        static assert(getInstTiargMod!()   == thisMod);
        static assert(getInstTiargFunc!()  == thisFunc);
        static assert(getInstTiargFunc2!() == thisFunc2);
        static assert(getInstTiargFunc3!() == thisFunc3);
    }
    nested(1, 1.0);

    auto funcLiteral = (int x, int y)
    {
        enum thisFunc  = "testkeyword.main.__lambda3";
        enum thisFunc2 = "testkeyword.main.__lambda3(int x, int y)";
        enum thisFunc3 = "_D11testkeyword4mainFNbAAyaZ9__lambda3MFiiZ";

        static assert(getFuncArgFile()  == thisFile);
        static assert(getFuncArgLine()  == 118);
        static assert(getFuncArgMod()   == thisMod);
        static assert(getFuncArgFunc()  == thisFunc);
        static assert(getFuncArgFunc2() == thisFunc2);
        static assert(getFuncArgFunc3() == thisFunc3);

        static assert(getFuncTiargFile()  == thisFile);
        static assert(getFuncTiargLine()  == 125);
        static assert(getFuncTiargMod()   == thisMod);
        static assert(getFuncTiargFunc()  == thisFunc);
        static assert(getFuncTiargFunc2() == thisFunc2);
        static assert(getFuncTiargFunc3() == thisFunc3);

        static assert(getInstTiargFile!()  == thisFile);
        static assert(getInstTiargLine!()  == 132);
        static assert(getInstTiargMod!()   == thisMod);
        static assert(getInstTiargFunc!()  == thisFunc);
        static assert(getInstTiargFunc2!() == thisFunc2);
        static assert(getInstTiargFunc3!() == thisFunc3);
    };
    funcLiteral(1, 2);

    static struct S
    {
        void func(string cs, T1, alias T2, T...)(int x) const
        {
            enum thisFunc       = `testkeyword.main.S.func!("foo", int, symbol, int[], float[]).func`;
            enum thisFunc2 = `void testkeyword.main.S.func!("foo", int, symbol, int[], float[]).func(int x) const`;
            enum thisFunc3 = `_D11testkeyword4mainFNbAAyaZ1S__T4funcVQpa3_666f6fTiS_DQCbQBrFNbQBpZ6symboliTAiTAfZQByMxFiZv`;

            static assert(getFuncArgFile()  == thisFile);
            static assert(getFuncArgLine()  == 149);
            static assert(getFuncArgMod()   == thisMod);
            static assert(getFuncArgFunc()  == thisFunc);
            static assert(getFuncArgFunc2() == thisFunc2);
            static assert(getFuncArgFunc3() == thisFunc3);

            static assert(getFuncTiargFile()  == thisFile);
            static assert(getFuncTiargLine()  == 156);
            static assert(getFuncTiargMod()   == thisMod);
            static assert(getFuncTiargFunc()  == thisFunc);
            static assert(getFuncTiargFunc2() == thisFunc2);
            static assert(getFuncTiargFunc3() == thisFunc3);

            static assert(getInstTiargFile!()  == thisFile);
            static assert(getInstTiargLine!()  == 163);
            static assert(getInstTiargMod!()   == thisMod);
            static assert(getInstTiargFunc!()  == thisFunc);
            static assert(getInstTiargFunc2!() == thisFunc2);
            static assert(getInstTiargFunc3!() == thisFunc3);
        }
    }
    static int symbol;
    S s;
    s.func!("foo", int, symbol, int[], float[])(1);
}
