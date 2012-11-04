// PERMUTE_ARGS: -release -gc

version(Windows)  {} // WIN64 ABI tests not included
else version(D_InlineAsm_X86_64)
{
	version = Run_X86_64_Tests;
}

extern (C) int printf(const char*, ...);
import std.stdio;

template tuple(A...) { alias A tuple; }

alias byte   B;
alias short  S;
alias int    I;
alias long   L;
alias float  F;
alias double D;
alias real   R;

// Single Type

struct b	{ B a;			}
struct bb	{ B a,b;		}
struct bbb	{ B a,b,c;		}
struct bbbb	{ B a,b,c,d;		}
struct bbbbb	{ B a,b,c,d, e;		}
struct b6	{ B a,b,c,d, e,f;	}
struct b7	{ B a,b,c,d, e,f,g;	}
struct b8	{ B a,b,c,d, e,f,g,h;	}
struct b9	{ B a,b,c,d, e,f,g,h, i;		}
struct b10	{ B a,b,c,d, e,f,g,h, i,j;		}
struct b11	{ B a,b,c,d, e,f,g,h, i,j,k;		}
struct b12	{ B a,b,c,d, e,f,g,h, i,j,k,l;		}
struct b13	{ B a,b,c,d, e,f,g,h, i,j,k,l, m;	}
struct b14	{ B a,b,c,d, e,f,g,h, i,j,k,l, m,n;	}
struct b15	{ B a,b,c,d, e,f,g,h, i,j,k,l, m,n,o;	}
struct b16	{ B a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p;	}
struct b17	{ B a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p, q;	}
struct b18	{ B a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p, q,r;	}
struct b19	{ B a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p, q,r,s;	}
struct b20	{ B a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p, q,r,s,t;}

struct s	{ S a;			}
struct ss	{ S a,b; 		}
struct sss	{ S a,b,c;		}
struct ssss	{ S a,b,c,d;		}
struct sssss	{ S a,b,c,d, e;		}
struct s6	{ S a,b,c,d, e,f;	}
struct s7	{ S a,b,c,d, e,f,g;	}
struct s8	{ S a,b,c,d, e,f,g,h;	}
struct s9	{ S a,b,c,d, e,f,g,h, i;}
struct s10	{ S a,b,c,d, e,f,g,h, i,j;}

struct i	{ I a;		}	struct l	{ L a;		}
struct ii	{ I a,b;	}	struct ll	{ L a,b;	}
struct iii	{ I a,b,c;	}	struct lll	{ L a,b,c;	}
struct iiii	{ I a,b,c,d;	}	struct llll	{ L a,b,c,d;	}
struct iiiii	{ I a,b,c,d,e;	}	struct lllll	{ L a,b,c,d,e;	}

struct f	{ F a;		}	struct d	{ D a;		}
struct ff	{ F a,b; 	}	struct dd	{ D a,b;	}
struct fff	{ F a,b,c;	}	struct ddd	{ D a,b,c;	}
struct ffff	{ F a,b,c,d;	}	struct dddd	{ D a,b,c,d;	}
struct fffff	{ F a,b,c,d,e;	}	struct ddddd	{ D a,b,c,d,e;	}

// Mixed Size

struct js	{ I a;   S b;	}
struct iss	{ I a;   S b,c;	}
struct  si	{ S a;   I b;	}
struct ssi	{ S a,b; I c;	}
struct sis	{ S a;   I b;  S c; }

struct ls	{ L a;   S b;	}
struct lss	{ L a;   S b,c;	}
struct  sl	{ S a;   L b;	}
struct ssl	{ S a,b; L c;	}
struct sls	{ S a;   L b;  S c; }

struct li	{ L a;   I b;	}
struct lii	{ L a;   I b,c;	}
struct  il	{ I a;   L b;	}
struct iil	{ I a,b; L c;	}
struct ili	{ I a;   L b;  I c; }

struct df	{ D a;   F b;	}
struct dff	{ D a;   F b,c;	}
struct  fd	{ F a;   D b;	}
struct ffd	{ F a,b; D c;	}
struct fdf	{ F a;   D b;  F c; }

// Mixed Types

struct fi	{ F a;   I b;	}	struct ffi	{ F a,b; I c;		}
struct fii	{ F a;   I b,c;	}	struct ffii	{ F a,b; I c,d;		}
struct  jf	{ I a;   F b;	}	struct  iff	{ I a;   F b,c;		}
struct iif	{ I a,b; F c;	}	struct iiff	{ I a,b; F c,d;		}
struct ifi	{ I a;   F b;  I c; }	struct ifif	{ I a;   F b;  I c; F d;}

struct di	{ D a;   I b;	}
struct dii	{ D a;   I b,c;	}
struct  id	{ I a;   D b;	}
struct iid	{ I a,b; D c;	}
struct idi	{ I a;   D b;  I c; }

// Real

struct r	{ R a;		}	 struct rr	{ R a,b;	}
struct rb	{ R a;   B b;	}	 struct br	{ B a;   R b;	}
struct rs	{ R a;   S b;	}	 struct sr	{ S a;   R b;	}
struct ri	{ R a;   I c;	}	 struct ir	{ I a;   R c;	}
struct rf	{ R a;   F b;	}	 struct fr	{ F a;   R b;	}


		// Int Registers only
alias tuple!(	b,bb,bbb,bbbb,bbbbb,
		b6, b7, b8, b9, b10,
		b11,b12,b13,b14,b15,
		b16,b17,b18,b19,b20,
		s,ss,sss,ssss,sssss,
		s6, s7, s8, s9, s10,
		i,ii,iii,iiii,iiiii,
		l,ll,lll,llll,lllll,
		//
		js,iss,si,ssi, sis,
		ls,lss,sl,ssl, sls,
		li,lii,il,iil, ili,
		fi,fii,jf,iif, ifi,
		ffi,ffii,iff,iiff,ifif,	// INT_END

		// SSE registers only
		f,ff,fff,ffff,fffff,
		d,dd,ddd,dddd,ddddd,
		//
		df,dff,fd,ffd, fdf,	// FLOAT_END

		// Int and SSE
		di,dii,id,iid, idi,	// MIX_END
		// ---
            ) ALL_T;

enum INT_END   = 65;
enum FLOAT_END = 80;
enum MIX_END   = ALL_T.length;


/* ***********************************************************************
                                   All
 ************************************************************************/
// test1 Struct passing and return

bool test0_pass = true;

T test0_out(T)( )
{
	T t;
	foreach( i, ref e; t.tupleof )  e = i+1;
	return t;
}
T test0_inout(T)( T t )
{
	foreach( i, ref e; t.tupleof )  e += 10;
	return t;
}

void test0_call_out(T)( )
{
	T t1;
	foreach( i, ref e; t1.tupleof ) e = i+1;
	T t2 = test0_out!(T)();

	if( t1 != t2 ) {
		test0_pass = false;
		printf( "Test0   out %-5s Fail\n", T.stringof.ptr );
	}
}
void test0_call_inout(T)( )
{
	T t1;
	foreach( i, ref e; t1.tupleof ) e = i+1;
	T t2 = test0_inout!(T)( t1 );
	foreach( i, ref e; t1.tupleof ) e += 10;

	if( t1 != t2 ) {
		test0_pass = false;
		printf( "Test0 inout %-5s Fail\n", T.stringof.ptr );
	}
}

void D_test0( )
{
	// Run Tests
	foreach( T; ALL_T )
	{
		test0_call_out!(T)();
		test0_call_inout!(T)();
	}

	// Real
	foreach( T; tuple!( r ,rb,rs,ri,rf, rr,br,sr,ir,fr ))
	{
		test0_call_out!(T)();
		test0_call_inout!(T)();
	}

	assert( test0_pass );
}

/* ***********************************************************************
                                X86_64
 ************************************************************************/

version(Run_X86_64_Tests)
{


struct TEST
{
	immutable int       num;
	immutable string    desc;
	bool[ALL_T.length]  result;
}

/**
 * 0 = Should Fail
 * 1 = Should Pass
 *
 * Issue 5570
 * Temporary Exceptions (force this test to pass)
 *
 * 3 = Should Pass Ignore
 * 7 = Should Pass Ignore Float/Int
 */
immutable int[ ALL_T.length ] expected =
	[
	1,1,1,1,1, // b
	1,1,1,1,1, // b6
	1,1,1,1,1, // b11
	1,0,0,0,0, // b16

	1,1,1,1,1, // s
	1,1,1,0,0, // s6
	1,1,1,1,0, // i
	1,1,0,0,0, // l
	1,1,1,1,1, // si mix
	1,1,1,1,0, // sl
	1,1,1,1,0, // il
	1,1,1,7,1, // int and float
	7,7,7,7,7, // int and float

	// SSE regs only
	1,1,3,1,0, // f
	1,1,0,0,0, // d
	3,1,3,1,0, // float and double

	// SSE + INT regs
	7,7,7,7,0, // int and double
	];


/**
 * value expected in registers [R1[,R2]]
 *
 * null means do not test
 * ( because value is passed on the stack ).
 */
immutable long[][] RegValue =
	[
/*   0  b	*/ [ 0x0000000000000001,                    ],
/*   1  bb	*/ [ 0x0000000000000201,                    ],
/*   2  bbb	*/ [ 0x0000000000030201,                    ],
/*   3  bbbb	*/ [ 0x0000000004030201,                    ],
/*   4  bbbbb	*/ [ 0x0000000504030201,                    ],
/*   5  b6	*/ [ 0x0000060504030201,                    ],
/*   6  b7	*/ [ 0x0007060504030201,                    ],
/*   7  b8	*/ [ 0x0807060504030201,                    ],
/*   8  b9	*/ [ 0x0807060504030201, 0x0000000000000009 ],
/*   9  b10	*/ [ 0x0807060504030201, 0x0000000000000a09 ],
/*  10  b11	*/ [ 0x0807060504030201, 0x00000000000b0a09 ],
/*  11  b12	*/ [ 0x0807060504030201, 0x000000000c0b0a09 ],
/*  12  b13	*/ [ 0x0807060504030201, 0x0000000d0c0b0a09 ],
/*  13  b14	*/ [ 0x0807060504030201, 0x00000e0d0c0b0a09 ],
/*  14  b15	*/ [ 0x0807060504030201, 0x000f0e0d0c0b0a09 ],
/*  15  b16	*/ [ 0x0807060504030201, 0x100f0e0d0c0b0a09 ],
/*  16  b17	*/ null,
/*  17  b18	*/ null,
/*  18  b19	*/ null,
/*  19  b20	*/ null,
/*  20  s	*/ [ 0x0000000000000001,                    ],
/*  21  ss	*/ [ 0x0000000000020001,                    ],
/*  22  sss	*/ [ 0x0000000300020001,                    ],
/*  23  ssss	*/ [ 0x0004000300020001,                    ],
/*  24  sssss	*/ [ 0x0004000300020001, 0x0000000000000005 ],
/*  25  s6	*/ [ 0x0004000300020001, 0x0000000000060005 ],
/*  26  s7	*/ [ 0x0004000300020001, 0x0000000700060005 ],
/*  27  s8	*/ [ 0x0004000300020001, 0x0008000700060005 ],
/*  28  s9	*/ null,
/*  29  s10	*/ null,
/*  30  i	*/ [ 0x0000000000000001,                    ],
/*  31  ii	*/ [ 0x0000000200000001,                    ],
/*  32  iii	*/ [ 0x0000000200000001, 0x0000000000000003 ],
/*  33  iiii	*/ [ 0x0000000200000001, 0x0000000400000003 ],
/*  34  iiiii	*/ null,
/*  35  l	*/ [ 0x0000000000000001,                    ],
/*  36  ll	*/ [ 0x0000000000000001, 0x0000000000000002 ],
/*  37  lll	*/ null,
/*  38  llll	*/ null,
/*  39  lllll	*/ null,

/*  40  js	*/ [ 0x0000000200000001,                    ],
/*  41  iss	*/ [ 0x0003000200000001,                    ],
/*  42  si	*/ [ 0x0000000200000001,                    ],
/*  43  ssi	*/ [ 0x0000000300020001,                    ],
/*  44  sis	*/ [ 0x0000000200000001, 0x0000000000000003 ],
/*  45  ls	*/ [ 0x0000000000000001, 0x0000000000000002 ],
/*  46  lss	*/ [ 0x0000000000000001, 0x0000000000030002 ],
/*  47  sl	*/ [ 0x0000000000000001, 0x0000000000000002 ],
/*  48  ssl	*/ [ 0x0000000000020001, 0x0000000000000003 ],
/*  49  sls	*/ null,
/*  50  li	*/ [ 0x0000000000000001, 0x0000000000000002 ],
/*  51  lii	*/ [ 0x0000000000000001, 0x0000000300000002 ],
/*  52  il	*/ [ 0x0000000000000001, 0x0000000000000002 ],
/*  53  iil	*/ [ 0x0000000200000001, 0x0000000000000003 ],
/*  54  ili	*/ null,

/*  55  fi	*/ [ 0x000000023f800000,                    ],
/*  56  fii	*/ [ 0x000000023f800000, 0x0000000000000003 ],
/*  57  jf	*/ [ 0x4000000000000001,                    ],
/*  58  iif	*/ [ 0x0000000200000001, 0x0000000040400000 ],
/*  59  ifi	*/ [ 0x4000000000000001, 0x0000000000000003 ],

/*  60  ffi	*/ [ 0x0000000000000003, 0x400000003f800000 ],
/*  61  ffii	*/ [ 0x0000000400000003, 0x400000003f800000 ],
/*  62  iff	*/ [ 0x4000000000000001, 0x0000000040400000 ],
/*  63  iiff	*/ [ 0x0000000200000001, 0x4080000040400000 ],
/*  64  ifif	*/ [ 0x4000000000000001, 0x4080000000000003 ],

/*  65  f	*/ [ 0x000000003f800000,                    ],
/*  66  ff	*/ [ 0x400000003f800000,                    ],
/*  67  fff	*/ [ 0x400000003f800000, 0x0000000040400000 ],
/*  68  ffff	*/ [ 0x400000003f800000, 0x4080000040400000 ],
/*  69  fffff	*/ null,
/*  70  d	*/ [ 0x3ff0000000000000,                    ],
/*  71  dd	*/ [ 0x3ff0000000000000, 0x4000000000000000 ],
/*  72  ddd	*/ null,
/*  73  dddd	*/ null,
/*  74  ddddd	*/ null,

/*  75  df	*/ [ 0x3ff0000000000000, 0x0000000040000000 ],
/*  76  dff	*/ [ 0x3ff0000000000000, 0x4040000040000000 ],
/*  77  fd	*/ [ 0x000000003f800000, 0x4000000000000000 ],
/*  78  ffd	*/ [ 0x400000003f800000, 0x4008000000000000 ],
/*  79  fdf	*/ null,

/*  80  di	*/ [ 0x3ff0000000000000, 0x0000000000000002 ],
/*  81  dii	*/ [ 0x3ff0000000000000, 0x0000000300000002 ],
/*  82  id	*/ [ 0x4000000000000000, 0x0000000000000001 ],
/*  83  iid	*/ [ 0x4008000000000000, 0x0000000200000001 ],
/*  84  idi	*/ null,
	];

/// iasm tests will dump values here
__gshared long[2] dump;
/**
 * Generate Register capture
 */
string gen_reg_capture( int n, string registers )( )
{
	if( RegValue[n] == null ) return "return;";

	string[] REG = mixin(registers); // ["RDI","RSI"];

	// Which type of compare
	static if(n < INT_END)
		enum MODE = 1; // Int
	else static if(n < FLOAT_END)
		enum MODE = 2; // Float
	else	enum MODE = 3; // Mix

	/* Begin */

	// Workaround iasm bug on OSX64 ( Issue 7354 )
	string code = "long dump0 = void; long dump1=void;\n";

	/*string*/ code ~= "asm {\n";

	final switch( MODE )
	{
		case 1: code ~= "mov [dump0], "~REG[0]~";\n";
			REG = REG[1..$];
		break;
		case 2:
		case 3: code ~= "movq [dump0], XMM0;\n";
	}

	if( RegValue[n].length == 2 )
	final switch( MODE )
	{
		case 1:
		case 3: code ~= "mov [dump1], "~REG[0]~";\n";
		break;
		case 2: code ~= "movq [dump1], XMM1;\n";
	}

	code ~= "}\n";

	return code ~ "dump[0]=dump0; dump[1]=dump1;\n";
}

/**
 * Clean Garbage out of Register
 */
void register_mask( T, int n )( )
{
	long[2] mask;
	foreach( m; __traits(allMembers, T) )
	{
		enum size = __traits(getMember, T, m).sizeof;
		enum off  = __traits(getMember, T, m).offsetof;

		long x = -1;
		x >>>= (8-size)*8; // Mask for member
		x  <<= (off &7)*8; // Move to offset

		// Accumulate masks
		if( off < 8 )
			mask[0] |= x;
		else	mask[1] |= x;
	}

	// for Mode 3, if double is last member
	if( is(T==id) || is(T==iid) )
	{
		dump[1] &= mask[0];
		dump[0] &= mask[1];
	} else {
		dump[0] &= mask[0];
		dump[1] &= mask[1];
	}
	/+
	import std.stdio;
	writefln( "MASK\t[ %16x, %16x ]", mask[0], mask[1] );
	writefln( "D %s\t[ %16x, %16x ]", T.stringof, dump[0], dump[1], );
	writef(   "C %s\t[ %16x", T.stringof, RegValue[n][0] );
	if( RegValue[n].length == 2 )
	writef( ", %16x", RegValue[n][1] );
	writefln( " ]\n" );
	// +/
}

/**
 * Check the results
 */
bool check( TEST data )
{
	bool pass = true;
	foreach( i, T; ALL_T )
	{
		auto e = expected[i];
		auto r = data.result[i];
		if( r != (e & 1) )
		{
			printf("Test%d %s \tFail", data.num, T.stringof.ptr);
			if( e & 2 )
			{	printf(" Ignore");
			} else	pass = false;
			if( e & 4 )
				printf(" MIX");
			printf("\n");
		}
	}
	assert(pass);
	return pass;
}

/************************************************************************/

// test1 Return Struct in Registers
// ( if RDI == 12 we have no hidden pointer )

TEST data1 = { 1, "RDI hidden pointer" };

T test1_asm( T, int n )( int i )
{
	asm {

	cmp EDI, 12;
	je L1;

	leave; ret;
	}
L1:
	data1.result[n] = true;
}

void test1()
{
	printf("\nRunning iasm Test 1 ( %s )\n", data1.desc.ptr);

	foreach( int n, T; ALL_T )
		test1_asm!(T,n)(12);

	check( data1 );
}

/************************************************************************/
// test2

TEST data2 = { 2, "Check Return Register value" };

void test2_run( T, int n )( )
{
	test2_ret!T();
	mixin( gen_reg_capture!(n,`["RAX","RDX"]`)() );

	// clean registers
	register_mask!(T,n)( );

	enum len = RegValue[n].length;
	if( dump[0..len] == RegValue[n] )
		data2.result[n] = true;
}

T test2_ret( T )( )
{
	T t;
	foreach( i, ref e; t.tupleof )  e = i+1;
	return t;
}

void test2()
{
	printf("\nRunning iasm Test 2 ( %s )\n", data2.desc.ptr);

	foreach( int n, T; ALL_T )
		test2_run!(T,n)( );

	check( data2 );
}

/************************************************************************/
// test3

TEST data3 = { 3, "Check Input Register value" };

void test3_run( T, int n )( T t )
{
	mixin( gen_reg_capture!(n,`["RDI","RSI"]`)() );

	// clean registers
	register_mask!(T,n)( );

	enum len = RegValue[n].length;
	if( dump[0..len] == RegValue[n] )
		data3.result[n] = true;
}

void test3()
{
	printf("\nRunning iasm Test 3 ( %s )\n", data3.desc.ptr);

	foreach( int n, T; ALL_T )
	{
		T t;
		foreach( i, ref e; t.tupleof )  e = i+1;
		test3_run!(T,n)( t );
	}
	check( data3 );
}


} // end version(Run_X86_64_Tests)

/************************************************************************/

void main()
{
	D_test0();

	version(Run_X86_64_Tests)
	{
		test1();
		test2();
		test3();
	}
}



/+
/**
 * C code to generate the table RegValue
 */
string c_generate_returns()
{
	string value =	" 1, 2, 3, 4, 5, 6, 7, 8, 9,10,"
			"11,12,13,14,15,16,17,18,19,20,";

	string code = "#include \"cgen.h\"\n";

	// Generate return functions
	foreach( int n, T; ALL_T )
	{
		auto Ts  = T.stringof;
		auto len = T.tupleof.length;

		code ~= "struct "~Ts~" func_ret_"~Ts~"(void) { \n";
		code ~= "struct "~Ts~" x = { ";
		code ~= value[0..len*3] ~ " };\n";
		code ~= "return x;\n}\n";
	}
	return code;
}
string c_generate_main()
{
	string code = "void main() {\n";

	foreach( int n, T; ALL_T )
	{
		// Which type of compare
		static if(n < INT_END)
			enum MODE = 1; // Int
		else static if(n < FLOAT_END)
			enum MODE = 2; // Float
		else	enum MODE = 3; // Mix

		auto nn  = n.stringof;
		auto Ts  = T.stringof;

		/* Begin */

		code ~= `printf("/* %3d  `~Ts~`\t*/ ", `~nn~`);`"\n";
		if( !(expected[n] & 1) )
		{
			code ~= `printf("null,\n");`"\n";
			continue;
		}
		code ~= "asm(\n";
		code ~= `"call func_ret_`~Ts~`\n"`"\n";
		final switch( MODE )
		{
		case 1:
		code ~= `"movq  %rax, reg\n" "movq  %rdx, reg+8\n"`;
		break;
		case 2:
		code ~= `"movq %xmm0, reg\n" "movq %xmm1, reg+8\n"`;
		break;
		case 3:
		code ~= `"movq %xmm0, reg\n" "movq  %rax, reg+8\n"`;
		}
		code ~= "\n);\n";

		code ~= `printf("[ 0x%016lx", reg.r1 );`"\n";

		if( T.sizeof > 8  || MODE == 3 )
			code ~= `printf(", 0x%016lx ],\n", reg.r2 );`"\n";
		else	code ~= `printf(",   %015c  ],\n", ' '    );`"\n";
	}
	return code ~ "}";
}
pragma(msg, c_generate_returns() );
pragma(msg, c_generate_main() );
// +/

/+
/**
 * Generate Functions that pass/return each Struct type
 *
 * ( Easier to look at objdump this way )
 */
string d_generate_functions( )
{
	string code = "extern(C) {";

	// pass
	foreach( s; ALL_T )
	{
		string ss = s.stringof;

		code ~= "void func_in_"~ss~"( "~ss~" t ) { t.a = 12; }\n";
	}
	// return
	foreach( s; ALL_T[0..10] )
	{
		string ss = s.stringof;

		code ~= `
		auto func_out_`~ss~`()
		{
			`~ss~` t;
			foreach( i, ref e; t.tupleof )  e = i+1;
			return t;
		}`;
	}
	// pass & return
	foreach( s; ALL_T[0..10] )
	{
		string ss = s.stringof;

		code ~= `
		auto func_inout_`~ss~`( `~ss~` t )
		{
			foreach( i, ref e; t.tupleof )  e += 10;
			return t;
		}`;
	}
	return code ~ "\n} // extern(C)\n";
}
//pragma( msg, d_generate_functions() );
mixin( d_generate_functions() );
// +/

