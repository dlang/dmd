// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

struct Tuple(T...){
	T expand;
	alias expand this;
}
auto tuple(T...)(T t){ return Tuple!T(t); }

/+struct TupleStaticForeach{ // should work, but is not the fault of the static foreach implementation.
	//pragma(msg, [tuple(1,"2",'3'),tuple(2,"3",'4')].map!((x)=>x));
	static foreach(a,b,c;[tuple(1,"2",'3'),tuple(2,"3",'4')].map!((x)=>x)){
		pragma(msg,a," ",b," ",c);
	}
}+/

void main(){
	static foreach(a,b,c;[tuple(1,"2",'3'),tuple(2,"3",'4')].map!((x)=>x)){
		pragma(msg, a," ",b," ",c);
	}
}

auto front(T)(T[] a){ return a[0]; }
auto popFront(T)(ref T[] a){ a=a[1..$]; }
auto empty(T)(T[] a){ return !a.length; }
auto back(T)(T[] a){ return a[$-1]; }
auto popBack(T)(ref T[] a){ a=a[0..$-1]; }

struct Iota(T){
	T s,e;
	@property bool empty(){ return s>=e; }
	@property T front(){ return s; }
	@property T back(){ return cast(T)(e-1); }
	void popFront(){ s++; }
	void popBack(){ e--; }
}
auto iota(T)(T s, T e){ return Iota!T(s,e); }

template map(alias a){
	struct Map(R){
		R r;
		@property front(){ return a(r.front); }
		@property back(){ return a(r.back); }
		@property bool empty(){ return r.empty; }
		void popFront(){ r.popFront(); }
		void popBack(){ r.popBack(); }
	}
	auto map(R)(R r){ return Map!R(r); }
}

template to(T:string){
	string to(S)(S x)if(is(S:int)||is(S:size_t)||is(S:char)){
		static if(is(S==char)) return cast(string)[x];
		if(x<0) return "-"~to(-x);
		if(x==0) return "0";
		return (x>=10?to(x/10):"")~cast(char)(x%10+'0');
	}
}
auto text(T)(T arg){ return to!string(arg); };

template all(alias a){
	bool all(R)(R r){
		foreach(x;r) if(!a(x)) return false;
		return true;
	}
}
template any(alias a){
	bool any(R)(R r){
		foreach(x;r) if(a(x)) return true;
		return false;
	}
}
auto join(R)(R r,string sep=""){
	string a;
	int first=0;
	foreach(x;r){
		if(first++) a~=sep;
		a~=x;
	}
	return a;
}

static foreach_reverse(x;iota(0,10).map!(to!string)){
    pragma(msg, x);
}

// create struct members iteratively
struct S{
    static foreach(i;a){
	    mixin("int x"~to!string(i)~";");
    }
    immutable int[] a = [0,1,2];
}
enum s=S(1,2,3);
pragma(msg, s);

// loop over struct members
static foreach(member;__traits(allMembers,S)){
    pragma(msg, member,": ",mixin("s."~member));
}

// print prime numbers using overload sets as state variables. :)
static assert(is(typeof(bad57)));
static assert(!is(typeof(bad53)));

static foreach(x;iota(2,100)){
    static foreach(y;iota(2,x)){
        static if(!(x%y)){
            mixin("void bad"~to!string(x)~"();");
        }
    }
    static if(!is(typeof(mixin("bad"~to!string(x))))){
        static assert(iota(2,x).all!(y=>!!(x%y)));
        pragma(msg, x);
    }else{
        static assert(iota(2,x).any!(y=>!(x%y)));
    }
}


alias Seq(T...)=T;

// simple boilerplate-free visitor pattern
static foreach(char T;'A'..'F'){
	mixin("class "~T~q{{
		void accept(Visitor v){
			return v.visit(this);
		}
	}});
}
alias Types = Seq!(mixin("Seq!("~iota('A','F').map!(to!string).join(", ")~")"));
abstract class Visitor{
	static foreach(T;Types){
		abstract void visit(T);
	}
}

string testVisitor(){
	string r;
	void writeln(T...)(T args){
		static foreach(x;args) r~=x;
		r~='\n';
	}
	class Visitor: .Visitor{
		static foreach(T;Types){
			override void visit(T){
				writeln("visited: ",T.stringof);
			}
		}
	}
	void main(){
		auto v=new Visitor;
		static foreach(T;Types){
			v.visit(new T);
		}
	}
	main();
	return r;
}
static assert(testVisitor()=="visited: A
visited: B
visited: C
visited: D
visited: E
");

// iterative computation over AliasSeq:
// (TODO: nice version with X template)
template staticMap(alias F,T...){
    alias state0=Seq!();
    static foreach(i,A;T){
        mixin("alias state"~to!string(i+1)~" = Seq!(state"~to!string(i)~",F!A);");
    }
    alias staticMap = Seq!(mixin("state"~to!string(T.length)));
}

alias arrayOf(T)=T[];
static assert(is(staticMap!(arrayOf,int,char,bool,Object)==Seq!(int[], char[], bool[], Object[])));
pragma(msg, staticMap!(arrayOf,int,char,bool,Object));




struct StaticForeachLoopVariable{
    int x;
    static foreach(i;0..1){
        mixin("enum x"~text(i)~" = i;");
    }
    int y;
    static assert(__traits(allMembers, StaticForeachLoopVariable).length==3);
    static assert(!is(typeof(StaticForeachLoopVariable.i)));
    static assert(!is(typeof(__traits(getMember, StaticForeachLoopVariable, "i"))));
}

struct StaticForeachScopeExit{
static:
    int[] test(){
        int[] r;
        scope(exit) r ~= 1234;
        {
            static foreach(i;0..5){
                scope(exit) r ~= i;
            }
            r ~= 5;
        }
        return r;
    }
    static assert(test()==[5,4,3,2,1,0]);
}

struct StaticForeachReverseHiding{
    static foreach(i;[0]){
        enum i = 1; // TODO: disallow?
        static assert(i==0);
    }
}

struct UnrolledForeachReverse{
static:
    alias Seq(T...)=T;
    int[] test(){
        int[] r;
        foreach_reverse(i;Seq!(0,1,2,3)){
            r~=i;
        }
        return r;
    }
    static assert(test()==[3,2,1,0]);
}

struct StaticForeachReverse{
static:
    alias Seq(T...)=T;
    int[] test(){
        int[] r;
        static foreach_reverse(i;0..4){
            r~=i;
        }
        return r;
    }
    static assert(test()==[3,2,1,0]);

    int[] test2(){
        int[] r;
        static foreach_reverse(i;[0,1,2,3]){
            r~=i;
        }
        return r;
    }
    static assert(test2()==[3,2,1,0]);

    int[] test3(){
        static struct S{
            int opApplyReverse(scope int delegate(int) dg){
                foreach_reverse(i;0..4) if(auto r=dg(i)) return r;
                return 0;
            }
        }
        int[] r;
        static foreach_reverse(i;S()){
            r~=i;
        }
        return r;
    }
    static assert(test3()==[3,2,1,0]);

    int[] test4(){
        int[] r;
        static foreach_reverse(i;Seq!(0,1,2,3)){
            r~=i;
        }
        return r;
    }
    static assert(test()==[3,2,1,0]);
}

struct StaticForeachByAliasDefault{
static:
    alias Seq(T...)=T;

    int[] test(){
        int a,b,c;
        static foreach(i,x;Seq!(a,b,c)) x=i;
        return [a,b,c];
    }
    static assert(test()==[0,1,2]);

    int[] test2(){
        int x=0;
        int foo(){ return ++x; }
        static foreach(y;Seq!foo)
            return [y,y,y];
    }
    static assert(test2()==[1,2,3]);

    void test3(){
        int x=0;
        int foo(){ return ++x; }
        static assert(!is(typeof({
            static foreach(enum y;Seq!foo)
                return [y,y,y];
        })));
    }
}

struct NestedStaticForeach{
    static:
    static foreach(i,name;["a"]){
        static foreach(j,name2;["d"]){
            mixin("enum "~name~name2~"=[i,j];");
        }
    }
    pragma(msg, ad);
}

struct TestAliasOutsideFunctionScope{
static:
    alias Seq(T...)=T;
    int a;
    static foreach(alias x;Seq!(a)){
    }
}

struct OpApplyMultipleStaticForeach{
static:
    struct OpApply{
        int opApply(scope int delegate(int,int) dg){
            foreach(i;0..10) if(auto r=dg(i,i*i)) return r;
            return 0;
        }
    }
    static foreach(a,b;OpApply()){
        mixin(`enum x`~cast(char)('0'+a)~"=b;");
    }
    static foreach(i;0..10){
        static assert(mixin(`x`~cast(char)('0'+i))==i*i);
    }
}


struct OpApplyMultipleStaticForeachLowered{
static:
    struct OpApply{
        int opApply(scope int delegate(int,int) dg){
            foreach(i;0..10) if(auto r=dg(i,i*i)) return r;
            return 0;
        }
    }
    static foreach(x;{
            static struct S(T...){ this(T k){ this.x=k; } T x; }
            static s(T...)(T a){ return S!T(a); }
            typeof({ foreach(a,b;OpApply()){ return s(a,b); } assert(0);}())[] r;
            foreach(a,b;OpApply()) r~=s(a,b);
            return r;
        }()){
        mixin(`enum x`~cast(char)('0'+x.x[0])~"=x.x[1];");
    }
    static foreach(i;0..10){
        static assert(mixin(`x`~cast(char)('0'+i))==i*i);
    }
}

struct RangeStaticForeach{
    static:
    struct Range{
        int x=0;
        this(int x){ this.x=x; }
        @property int front(){ return x; }
        void popFront(){ x += 2; }
        @property bool empty(){ return x>=10; }
    }
    static foreach(i;Range()){
        mixin(`enum x`~cast(char)('0'+i)~"=i;");
    }
    static foreach(i;0..5){
        static assert(mixin(`x`~cast(char)('0'+2*i))==2*i);
    }
    static assert(!is(typeof({
        struct S{
            static foreach(i,k;Range()){}
        }
    })));
    static foreach(k;Range()){} // ok
}

struct OpApplySingleStaticForeach{
    static:
    struct OpApply{
        int opApply(scope int delegate(int) dg){
            foreach(i;0..10) if(auto r=dg(i)) return r;
            return 0;
        }
    }
    static foreach(b;OpApply()){
        mixin(`enum x`~cast(char)('0'+b)~"=b;");
    }
    static foreach(i;0..10){
        static assert(mixin(`x`~cast(char)('0'+i))==i);
    }
}

struct TypeStaticForeach{
static:
    alias Seq(T...)=T;
    static foreach(i,alias T;Seq!(int,double,char)){
        mixin(`T x`~cast(char)('0'+i)~";");
    }
    pragma(msg, "x0: ",typeof(x0));
    pragma(msg, "x1: ",typeof(x1));
    pragma(msg, "x2: ",typeof(x2));
    static assert(is(typeof(x0)==int));
    static assert(is(typeof(x1)==double));
    static assert(is(typeof(x2)==char));
}

struct AliasForeach{
static:
    alias Seq(T...)=T;
    int[] test(){
        int a,b,c;
        static foreach(x;Seq!(a,b,c,2)){
            static if(is(typeof({x=2;}))) x=2;
        }
        int x,y,z;
        static foreach(alias k;Seq!(x,y,z,2)){
            static if(is(typeof({k=2;}))) k=2;
        }
        int j,k,l;
        static assert(!is(typeof({
            static foreach(ref x;Seq!(j,k,l,2)){
                static if(is(typeof({x=2;}))) x=2;
            }
        })));
        return [x,y,z];
    }
    static assert(test()==[2,2,2]);
}

struct EnumForeach{
static:
    alias Seq(T...)=T;
    int a=1;
    int fun(){ return 1; }
    int gun(){ return 2; }
    int hun(){ return 3;}
    auto test(){
        static foreach(i,enum x;Seq!(fun,gun,hun)){
            static assert(i+1==x);
        }
        foreach(i,enum x;Seq!(fun,gun,hun)){
            static assert(i+1==x);
        }
    }
}

struct TestUninterpretable{
static:
    alias Seq(T...)=T;
    auto test(){
        int k;
        static assert(!is(typeof({
            static foreach(x;[k]){}
        })));
        static assert(!is(typeof({
            foreach(enum x;[1,2,3]){}
        })));
        static assert(!is(typeof({
            foreach(alias x;[1,2,3]){}
        })));
        foreach(enum x;Seq!(1,2,3)){} // ok
        foreach(alias x;Seq!(1,2,3)){} // ok
        static foreach(enum x;[1,2,3]){} // ok
        static foreach(alias x;[1,2,3]){} // ok
        static assert(!is(typeof({
            static foreach(enum alias x;[1,2,3]){}
        })));
        int x;
        static foreach(i;Seq!x){ } // ok
        static foreach(i,j;Seq!(1,2,x)){ } // ok
        static assert(!is(typeof({
            static foreach(ref x;[1,2,3]){}
        })));
    }
}

struct SeqForeachConstant{
static:
    alias Seq(T...)=T;
	static assert(!is(typeof({
        foreach(x;Seq!1) x=2;
	})));
    int test2(){
        int r=0;
        foreach(x;Seq!(1,2,3)){
            enum k=x;
            r+=k;
        }
        return r;
    }
    static assert(test2()==6);
}

struct SeqForeachBreakContinue{
static:
    alias Seq(T...)=T;
    int[] test(){
        int[] r;
        foreach(i;Seq!(0,1,2,3,4,5)){
            if(i==2) continue;
            if(i==4) break;
            r~=i;
        }
        return r;
    }
    static assert(test()==[0,1,3]);
}

struct TestStaticForeach{
static:
    int test(int x){
        int r=0;
        switch(x){
            static foreach(i;0..10){
                case i: r=i; break;
            }
            default: r=-1; break;
        }
        return r;
    }
    static foreach(i;0..15){
        pragma(msg, "test(",i,")→ ",test(i));
        static assert(test(i)==(i<10?i:-1));
    }

    enum x=[1,2,3];

    static foreach(i;x){
        mixin("enum x"~cast(char)('0'+i)~"="~cast(char)('0'+i)~";");
    }

    static foreach(i;x){
        pragma(msg, mixin("x"~cast(char)('0'+i)));
        pragma(msg,x);
    }

    int[] noBreakNoContinue(){
        int[] r;
        static foreach(i;0..1){
            // if(i==3) continue; // TODO: error?
            // if(i==7) break; // TODO: error?
            r~=i;
        }
        return r;
    }

    mixin("enum k=3;");
}

static foreach(i,j;[1,2,3]){
    pragma(msg, i," ",j);
}

void testtest(){
    static foreach(i,v;[1,2,3]){
        pragma(msg, i," ",v);
        static assert(i+1 == v);
    }
}


static foreach(i;Seq!(1,2,3,4,int)){
    static if(!is(i) && i!=2){
        pragma(msg, i);
    }
}

int fun(int x){
    int r=0;
    switch(x){
        static foreach(i;Seq!(0,1,2,3,4,5,6)){
            static if (i < 5)
                case i: r=i; break; // TODO: error?
        }
        default: r=-1; break;
    }
    return r;
}

static foreach(i;0..10) static assert(fun(i)==(i<5?i:-1));

static foreach(i;0..0) { }
void testEmpty(){
    static foreach(i;0..0) { }
}

