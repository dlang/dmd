// Pick a memory type for __c_wchar_t,
// doesn't really matter what for the purposes of testing implicit conversions
enum __c_wchar_t : wchar;

alias wchar_t = __c_wchar_t;
alias wtstring = immutable(wchar_t)[];
wtstring             a = "somestring";
const(wchar_t)[]     b = "somestring";
immutable(wchar_t)*  c = "somestring";
const(wchar_t)*      d = "somestring";

string foo = "foo";

static assert(!__traits(compiles, { immutable(wchar_t)[] bar = foo; } ));
static assert(!__traits(compiles, { const(wchar_t)[]     bar = foo; } ));
static assert(!__traits(compiles, { immutable(wchar_t)*  bar = foo; } ));
static assert(!__traits(compiles, { const(wchar_t)*      bar = foo; } ));

void ss (string   x) {}
void sw (wstring  x) {}
void sd (dstring  x) {}
void swt(wtstring x) {}

void ps (const(char)*    x) {}
void pw (const(wchar)*   x) {}
void pd (const(dchar)*   x) {}
void pwt(const(wchar_t)* x) {}

alias AliasSeq(T...) = T;
void test()
{
    string s;
    wstring ws;
    dstring ds;
    wtstring wts;

    const(char)* p;
    const(wchar)* wp;
    const(dchar)* dp;
    const(wchar_t)* wtp;
    // non-Litral implicit conversion should only work where the memory type is the same.
    sw (wts); //
    swt(ws);  //
    
    if (ws == wts) {} //
    if (wp == wtp) {}
    ws = wts; //
    wts = ws; //
    
    wp = wtp;
    wtp = wp; //
    if (ws.ptr == wts.ptr) {}
    if (wts.ptr == ws.ptr) {}
    
    static foreach(f; AliasSeq!(sw,sd,swt))
    {
        static assert(!__traits(compiles, { f(s); }));
    }
    static foreach(f; AliasSeq!(sw,ss,swt))
    {
        static assert(!__traits(compiles, { f(ds); }));
    }
    
    // Check that string literals to functions work
    ss (""); ps ("");
    sw (""); pw ("");
    sd (""); pd ("");
    swt(""); pwt("");
    
    wchar[5] w;
    wchar_t[5] wt;

    pw (w.ptr);
    pwt(w.ptr);
    pw (wt.ptr);
    pwt(wt.ptr);

}
