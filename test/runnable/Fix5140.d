// PERMUTE_ARGS:
// EXTRA_SOURCES: imports/Fix5140a_file.d
module Fix5140;
import imports.Fix5140a;

static assert(getCallingFunc() == "");
static assert(getTemplCallingFunc() == "");
static assert(getCalleeFunc() == "imports.Fix5140a.getCalleeFunc");

static assert(getCallingPrettyFunc() == "");
static assert(getTemplCallingPrettyFunc() == "");
static assert(getCalleePrettyFunc(1, 1.0) == "string imports.Fix5140a.getCalleePrettyFunc(int x, float y)");

static assert(getCallingModule() == "Fix5140");
static assert(getTemplCallingModule() == "Fix5140");
static assert(getCalleeModule() == "imports.Fix5140a");

void main(string[] args) nothrow
{
    static assert(getCallingModule() == "Fix5140");
    static assert(getTemplCallingModule() == "Fix5140");
    static assert(getCalleeModule() == "imports.Fix5140a");

    static assert(getCallingFunc() == "Fix5140.main");
    static assert(getTemplCallingFunc() == "Fix5140.main");
    static assert(getCalleeFunc() == "imports.Fix5140a.getCalleeFunc");

    static assert(getCallingPrettyFunc() == "void Fix5140.main(string[] args) nothrow");
    static assert(getTemplCallingPrettyFunc() == "void Fix5140.main(string[] args) nothrow");
    static assert(getCalleePrettyFunc(1, 1.0) == "string imports.Fix5140a.getCalleePrettyFunc(int x, float y)");

    void nested(int x, float y) nothrow
    {
        static assert(getCallingModule() == "Fix5140");
        static assert(getTemplCallingModule() == "Fix5140");
        static assert(getCalleeModule() == "imports.Fix5140a");

        static assert(getCallingFunc() == "Fix5140.main.nested");
        static assert(getTemplCallingFunc() == "Fix5140.main.nested");
        static assert(getCalleeFunc() == "imports.Fix5140a.getCalleeFunc");

        static assert(getCallingPrettyFunc() == "void Fix5140.main.nested(int x, float y) nothrow");
        static assert(getTemplCallingPrettyFunc() == "void Fix5140.main.nested(int x, float y) nothrow");
        static assert(getCalleePrettyFunc(1, 1.0) == "string imports.Fix5140a.getCalleePrettyFunc(int x, float y)");
    }
    nested(1, 1.0);

    auto funcLiteral = (int x, int y)
    {
        static assert(getCallingModule() == "Fix5140");
        static assert(getTemplCallingModule() == "Fix5140");
        static assert(getCalleeModule() == "imports.Fix5140a");

        static assert(getCallingFunc() == "Fix5140.main.__lambda1");
        static assert(getTemplCallingFunc() == "Fix5140.main.__lambda1");
        static assert(getCalleeFunc() == "imports.Fix5140a.getCalleeFunc");

        static assert(getCallingPrettyFunc() == "Fix5140.main.__lambda1(int x, int y)");
        static assert(getTemplCallingPrettyFunc() == "Fix5140.main.__lambda1(int x, int y)");
        static assert(getCalleePrettyFunc(1, 1.0) == "string imports.Fix5140a.getCalleePrettyFunc(int x, float y)");
    };
    funcLiteral(1, 2);

    static struct S
    {
        void func(string cs, T1, alias T2, T...)(int x) const
        {
            static assert(getCallingModule() == "Fix5140");
            static assert(getTemplCallingModule() == "Fix5140");
            static assert(getCalleeModule() == "imports.Fix5140a");

            static assert(getCallingFunc() == "Fix5140.main.S.func!(\"foo\", int, symbol, int[], float[]).func");
            static assert(getTemplCallingFunc() == "Fix5140.main.S.func!(\"foo\", int, symbol, int[], float[]).func");
            static assert(getCalleeFunc() == "imports.Fix5140a.getCalleeFunc");

            static assert(getCallingPrettyFunc() == "void Fix5140.main.S.func!(\"foo\", int, symbol, int[], float[]).func(int x) const");
            static assert(getTemplCallingPrettyFunc() == "void Fix5140.main.S.func!(\"foo\", int, symbol, int[], float[]).func(int x) const");
            static assert(getCalleePrettyFunc(1, 1.0) == "string imports.Fix5140a.getCalleePrettyFunc(int x, float y)");
        }
    }
    static int symbol;
    S s;
    s.func!("foo", int, symbol, int[], float[])(1);
}
