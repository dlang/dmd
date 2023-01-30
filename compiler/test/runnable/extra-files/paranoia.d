module paranoia;

/*	A D version of Kahan's Floating Point Test "Paranoia"

			Rainer Schuetze, April 2018

	This is a translation from the C version
	(http://www.netlib.org/paranoia/paranoia.c) by

			Thos Sumner, UCSF, Feb. 1985
			David Gay, BTL, Jan. 1986

	This is a rewrite from the Pascal version by

			B. A. Wichmann, 18 Jan. 1985

	(and does NOT exhibit good C programming style).

	Adjusted to use Standard C headers 19 Jan. 1992 (dmg);
	compile with -DKR_headers or insert
#define KR_headers
	at the beginning if you have an old-style C compiler.

(C) Apr 19 1983 in BASIC version by:
	Professor W. M. Kahan,
	567 Evans Hall
	Electrical Engineering & Computer Science Dept.
	University of California
	Berkeley, California 94720
	USA

converted to Pascal by:
	B. A. Wichmann
	National Physical Laboratory
	Teddington Middx
	TW11 OLW
	UK

converted to C by:

	David M. Gay		and	Thos Sumner
	AT&T Bell Labs			Computer Center, Rm. U-76
	600 Mountain Avenue		University of California
	Murray Hill, NJ 07974		San Francisco, CA 94143
	USA				USA

with simultaneous corrections to the Pascal source (reflected
in the Pascal source available over netlib).
[A couple of bug fixes from dgh = sun!dhough incorporated 31 July 1986.]

Reports of results on various systems from all the versions
of Paranoia are being collected by Richard Karpinski at the
same address as Thos Sumner.  This includes sample outputs,
bug reports, and criticisms.

You may copy this program freely if you acknowledge its source.
Comments on the Pascal version to NPL, please.


The C version catches signals from floating-point exceptions.
If signal(SIGFPE,...) is unavailable in your environment, you may
#define NOSIGNAL to comment out the invocations of signal.

This source file is too big for some C compilers, but may be split
into pieces.  Comments containing "SPLIT" suggest convenient places
for this splitting.  At the end of these comments is an "ed script"
(for the UNIX(tm) editor ed) that will do this splitting.

By #defining Single when you compile this source, you may obtain
a single-precision C version of Paranoia.


The following is from the introductory commentary from Wichmann's work:

The BASIC program of Kahan is written in Microsoft BASIC using many
facilities which have no exact analogy in Pascal.  The Pascal
version below cannot therefore be exactly the same.  Rather than be
a minimal transcription of the BASIC program, the Pascal coding
follows the conventional style of block-structured languages.  Hence
the Pascal version could be useful in producing versions in other
structured languages.

Rather than use identifiers of minimal length (which therefore have
little mnemonic significance), the Pascal version uses meaningful
identifiers as follows [Note: A few changes have been made for C]:


BASIC   C               BASIC   C               BASIC   C

   A                       J                       S    StickyBit
   A1   AInverse           J0   NoErrors           T
   B    Radix                    [Failure]         T0   Underflow
   B1   BInverse           J1   NoErrors           T2   ThirtyTwo
   B2   RadixD2                  [SeriousDefect]   T5   OneAndHalf
   B9   BMinusU2           J2   NoErrors           T7   TwentySeven
   C                             [Defect]          T8   TwoForty
   C1   CInverse           J3   NoErrors           U    OneUlp
   D                             [Flaw]            U0   UnderflowThreshold
   D4   FourD              K    PageNo             U1
   E0                      L    Milestone          U2
   E1                      M                       V
   E2   Exp2               N                       V0
   E3                      N1                      V8
   E5   MinSqEr            O    Zero               V9
   E6   SqEr               O1   One                W
   E7   MaxSqEr            O2   Two                X
   E8                      O3   Three              X1
   E9                      O4   Four               X8
   F1   MinusOne           O5   Five               X9   Random1
   F2   Half               O8   Eight              Y
   F3   Third              O9   Nine               Y1
   F6                      P    Precision          Y2
   F9                      Q                       Y9   Random2
   G1   GMult              Q8                      Z
   G2   GDiv               Q9                      Z0   PseudoZero
   G3   GAddSub            R                       Z1
   H                       R1   RMult              Z2
   H1   HInverse           R2   RDiv               Z9
   I                       R3   RAddSub
   IO   NoTrials           R4   RSqrt
   I3   IEEE               R9   Random9

   SqRWrng

All the variables in BASIC are true variables and in consequence,
the program is more difficult to follow since the "constants" must
be determined (the glossary is very helpful).  The Pascal version
uses Real constants, but checks are added to ensure that the values
are correctly converted by the compiler.

The major textual change to the Pascal version apart from the
identifiersis that named procedures are used, inserting parameters
wherehelpful.  New procedures are also introduced.  The
correspondence is as follows:


BASIC       Pascal
lines

  90- 140   Pause
 170- 250   Instructions
 380- 460   Heading
 480- 670   Characteristics
 690- 870   History
2940-2950   Random
3710-3740   NewD
4040-4080   DoesYequalX
4090-4110   PrintIfNPositive
4640-4850   TestPartialUnderflow

=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=

Below is an "ed script" that splits para.c into 10 files
of the form part[1-8].c, subs.c, and msgs.c, plus a header
file, paranoia.h, that these files require.

r paranoia.c
$
?SPLIT
 .d
+d
-,$w msgs.c
-,$d
?SPLIT
 .d
+d
-,$w subs.c
-,$d
?part8
+d
?include
 .,$w part8.c
 .,$d
-d
?part7
+d
?include
 .,$w part7.c
 .,$d
-d
?part6
+d
?include
 .,$w part6.c
 .,$d
-d
?part5
+d
?include
 .,$w part5.c
 .,$d
-d
?part4
+d
?include
 .,$w part4.c
 .,$d
-d
?part3
+d
?include
 .,$w part3.c
 .,$d
-d
?part2
+d
?include
 .,$w part2.c
 .,$d
?SPLIT
 .d
1,/^#include/-1d
1,$w part1.c
/Computed constants/,$d
1,$s/^int/extern &/
1,$s/^FLOAT/extern &/
1,$s/^char/extern &/
1,$s! = .*!;!
/^Guard/,/^Round/s/^/extern /
/^jmp_buf/s/^/extern /
/^Sig_type/s/^/extern /
s/$/\
extern void sigfpe(INT);/
w paranoia.h
q

*/

import core.stdc.stdio;
import core.stdc.signal;
import core.stdc.stdlib;
import std.math : fabs, floor, log, sqrt, pow;

// default to double
version(Single) {} else
version(Extended) {} else
version(ExtendedSoft) {} else
version = Double;

version = NOSIGNAL;
version = NOPAUSE;

version(ExtendedSoft) // inaccuracy of C runtime sqrt function
	enum relaxedChecks = true;
else version(CTFE)
	enum relaxedChecks = true;
else
	enum relaxedChecks = false;

version(Single) {
alias  float  FLOAT;
alias  FLOAT  toFLOAT;
 auto  FABS(  ARG1 )(ARG1  x) { return cast(float)fabs(cast(double)x); }
 auto  FLOOR(  ARG1 )(ARG1  x) { return cast(float)floor(cast(double)x); }
 auto  LOG(  ARG1 )(ARG1  x) { return cast(float)log(cast(double)x); }
 auto  POW(  ARG1,  ARG2 )(ARG1  x, ARG2  y) { return cast(float)pow(cast(double)x,cast(double)y); }
 auto  SQRT(  ARG1 )(ARG1  x) { return cast(float)sqrt(cast(double)x); }
void  printFLOAT(const(char) *fmt, FLOAT  f) { printf(fmt, f); }
} else  version(Double) {
alias  double  FLOAT;
alias  FLOAT  toFLOAT;
 auto  FABS(  ARG1 )(ARG1  x) { return  fabs(x); }
 auto  FLOOR(  ARG1 )(ARG1  x) { return  floor(x); }
 auto  LOG(  ARG1 )(ARG1  x) { return  log(x); }
 auto  POW(  ARG1,  ARG2 )(ARG1  x, ARG2  y) { return  pow(x,y); }
 auto  SQRT(  ARG1 )(ARG1  x) { return  sqrt(x); }
void  printFLOAT(const(char) *fmt, FLOAT  f) { printf(fmt, f); }
} else  version(Extended) {
alias  real FLOAT;
alias  FLOAT  toFLOAT;
 auto  FABS(  ARG1 )(ARG1  x) { return  fabs(x); }
 auto  FLOOR(  ARG1 )(ARG1  x) { return  floor(x); }
 auto  LOG(  ARG1 )(ARG1  x) { return  log(x); }
 auto  POW(  ARG1,  ARG2 )(ARG1  x, ARG2  y) { return  pow(x,y); }
 auto  SQRT(  ARG1 )(ARG1  x) { return  sqrt(x); }
void  printFLOAT(const(char) *fmt, FLOAT  f) { printExtended(fmt, f); }
} else version(ExtendedSoft) {
import dmd.root.longdouble;
alias  longdouble_soft  FLOAT;
alias  longdouble_soft  toFLOAT;
 auto  FABS(  ARG1 )(ARG1  x) { return   fabsl(x); }
 auto  FLOOR(  ARG1 )(ARG1  x) { return  toFLOAT(floor(cast(double)x)); }
 auto  LOG(  ARG1 )(ARG1  x) { return    toFLOAT(log(cast(double)x)); }
 auto  POW(  ARG1,  ARG2 )(ARG1  x, ARG2  y) { return  toFLOAT(pow(cast(double)x,cast(double)y)); }
 auto  SQRT(  ARG1 )(ARG1  x) { return   sqrtl(toFLOAT(x)); }
void  printFLOAT(const(char) *fmt, FLOAT  f) { printExtended(fmt, f); }
}
else static assert(false, "no floating point type selected");

version(Single) {} else
version(Double) {} else
void printExtended(const(char) *fmt, FLOAT f)
{
	version(CTFE)
		return;

	else version(CRuntime_Microsoft)
	{
		import dmd.root.longdouble;
		char[64] str;
		if (cast(double)f == f)
			printf("%lg", cast(double)f);
		else
		{
			ld_sprint(str.ptr, str.length, 'A', longdouble_soft(f));
			printf("%s", str.ptr);
		}
	}
	else
		printf("%Lg", f);
}



version(NOSIGNAL) {
	alias jmp_buf = int;
	const jmp_buf ovfl_buf = 0;
	int setjmp(const jmp_buf) { return 0; }
}
else
{
	jmp_buf  ovfl_buf;
}

// not #if KR_headers










alias  void  VOID;
alias  int  INT;
alias  FLOAT  FP;
alias  const(char) *CHARP;
alias  const(char) **CHARPP;

alias  void function(int) Sig_type;
FLOAT  Sign(FLOAT);
FLOAT  Random();

// embed everything into struct to avoid globals
struct Paranoia {

Sig_type  sigsave;

enum  KEYBOARD = 0;

FLOAT  Radix, BInvrse, RadixD2, BMinusU2;

/*Small floating point constants.*/
FLOAT  Zero;
FLOAT  Half;
FLOAT  One;
FLOAT  Two;
FLOAT  Three;
FLOAT  Four;
FLOAT  Five;
FLOAT  Eight;
FLOAT  Nine;
FLOAT  Ten;
FLOAT  TwentySeven;
FLOAT  ThirtyTwo;
FLOAT  TwoForty;
FLOAT  MinusOne;
FLOAT  OneAndHalf;

/*Integer constants*/
int  NoTrials = 20; /*Number of tests for commutativity. */
enum  False = 0;
enum  True = 1;

/* Definitions for declared types
	Guard == (Yes, No);
	Rounding == (Chopped, Rounded, Other);
	Message == packed array [1..40] of char;
	Class == (Flaw, Defect, Serious, Failure);
	  */
enum  Yes = 1;
enum  No =  0;
enum  Chopped = 2;
enum  Rounded = 1;
enum  Other =   0;
enum  Flaw =    3;
enum  Defect =  2;
enum  Serious = 1;
enum  Failure = 0;
alias  int  Guard, Rounding, Class;
alias  char  Message;

/* Declarations of Variables */
int  Indx;
char[8]  ch;
FLOAT  AInvrse, A1;
FLOAT  C, CInvrse;
FLOAT  D, FourD;
FLOAT  E0, E1, Exp2, E3, MinSqEr;
FLOAT  SqEr, MaxSqEr, E9;
FLOAT  Third;
FLOAT  F6, F9;
FLOAT  H, HInvrse;
int  I;
FLOAT  StickyBit, J;
FLOAT  MyZero;
FLOAT  Precision;
FLOAT  Q, Q9;
FLOAT  R, Random9;
FLOAT  T, Underflow, S;
FLOAT  OneUlp, UfThold, U1, U2;
FLOAT  V, V0, V9;
FLOAT  W;
FLOAT  X, X1, X2, X8, Random1;
FLOAT  Y, Y1, Y2, Random2;
FLOAT  Z, PseudoZero, Z1, Z2, Z9;
int[4]  ErrCnt;
int  fpecount;
int  Milestone;
int  PageNo;
int  M, N, N1;
Guard  GMult, GDiv, GAddSub;
Rounding  RMult, RDiv, RAddSub, RSqrt;
int  Break, Done, NotMonot, Monot, Anomaly, IEEE,
		SqRWrng, UfNGrad;
/* Computed constants. */
/*U1  gap below 1.0, i.e, 1.0-U1 is next number below 1.0 */
/*U2  gap above 1.0, i.e, 1.0+U2 is next number above 1.0 */

/* floating point exception receiver */
version(NOSIGNAL)
	Sig_type sigfpe = null;
else
void
 sigfpe(INT  x)
{
	fpecount++;
	printf("\n* * * FLOATING-POINT ERROR %d * * *\n", x);
	fflush(stdout);
	if (sigsave) {
		version(NOSIGNAL) {} else
			signal(SIGFPE, sigsave);
		sigsave = 0;
		longjmp(ovfl_buf, 1);
		}
	exit(1);
}

int  main()
{
	/* First two assignments use integer right-hand sides. */
	Zero = 0;
	One = 1;
	Two = One + One;
	Three = Two + One;
	Four = Three + One;
	Five = Four + One;
	Eight = Four + Four;
	Nine = Three * Three;
	Ten = Five * Two;
	TwentySeven = Nine * Three;
	ThirtyTwo = Four * Eight;
	TwoForty = Four * Five * Three * Four;
	MinusOne = -One;
	Half = One / Two;
	OneAndHalf = One + Half;
	ErrCnt[Failure] = 0;
	ErrCnt[Serious] = 0;
	ErrCnt[Defect] = 0;
	ErrCnt[Flaw] = 0;
	PageNo = 1;
	/*=============================================*/
	Milestone = 0;
	/*=============================================*/
	version(NOSIGNAL) {} else
		signal(SIGFPE, sigfpe);

	Instructions();
	Pause();
	Heading();
	Pause();
	Characteristics();
	Pause();
	History();
	Pause();
	/*=============================================*/
	Milestone = 7;
	/*=============================================*/
	printf("Program is now RUNNING tests on small integers:\n");

	TstCond (Failure, (Zero + Zero == Zero) && (One - One == Zero)
		   && (One > Zero) && (One + One == Two),
			"0+0 != 0, 1-1 != 0, 1 <= 0, or 1+1 != 2");
	Z = - Zero;
	if (Z != 0.0) {
		ErrCnt[Failure] = ErrCnt[Failure] + 1;
		printf("Comparison alleges that -0.0 is Non-zero!\n");
		U2 = 0.001;
		Radix = 1;
		TstPtUf();
		}
	TstCond (Failure, (Three == Two + One) && (Four == Three + One)
		   && (Four + Two * (- Two) == Zero)
		   && (Four - Three - One == Zero),
		   "3 != 2+1, 4 != 3+1, 4+2*(-2) != 0, or 4-3-1 != 0");
	TstCond (Failure, (MinusOne == (0 - One))
		   && (MinusOne + One == Zero ) && (One + MinusOne == Zero)
		   && (MinusOne + FABS(One) == Zero)
		   && (MinusOne + MinusOne * MinusOne == Zero),
		   "-1+1 != 0, (-1)+abs(1) != 0, or -1+(-1)*(-1) != 0");
	TstCond (Failure, Half + MinusOne + Half == Zero,
		  "1/2 + (-1) + 1/2 != 0");
	/*=============================================*/
	/*SPLIT
	{
		extern void part2(), part3(), part4(),
			part5(), part6(), part7();
		int part8();

		part2();
		part3();
		part4();
		part5();
		part6();
		part7();
		return part8();
		}
	}
#include "paranoia.h"
void part2(){
*/
	Milestone = 10;
	/*=============================================*/
	TstCond (Failure, (Nine == Three * Three)
		   && (TwentySeven == Nine * Three) && (Eight == Four + Four)
		   && (ThirtyTwo == Eight * Four)
		   && (ThirtyTwo - TwentySeven - Four - One == Zero),
		   "9 != 3*3, 27 != 9*3, 32 != 8*4, or 32-27-4-1 != 0");
	TstCond (Failure, (Five == Four + One) &&
			(TwoForty == Four * Five * Three * Four)
		   && (TwoForty / Three - Four * Four * Five == Zero)
		   && ( TwoForty / Four - Five * Three * Four == Zero)
		   && ( TwoForty / Five - Four * Three * Four == Zero),
		  "5 != 4+1, 240/3 != 80, 240/4 != 60, or 240/5 != 48");
	if (ErrCnt[Failure] == 0) {
		printf("-1, 0, 1/2, 1, 2, 3, 4, 5, 9, 27, 32 & 240 are O.K.\n");
		printf("\n");
		}
	printf("Searching for Radix and Precision.\n");
	W = One;
	do  {
		W = W + W;
		Y = W + One;
		Z = Y - W;
		Y = Z - One;
		} while (MinusOne + FABS(Y) < Zero);
	/*.. now W is just big enough that |((W+1)-W)-1| >= 1 ...*/
	Precision = Zero;
	Y = One;
	do  {
		Radix = W + Y;
		Y = Y + Y;
		Radix = Radix - W;
		} while ( Radix == Zero);
	if (Radix < Two) Radix = One;
    printf("Radix = "); printFLOAT("%f", Radix); printf (" .\n");
	if (Radix != 1) {
		W = One;
		do  {
			Precision = Precision + One;
			W = W * Radix;
			Y = W + One;
			} while ((Y - W) == One);
		}
	/*... now W == Radix^Precision is barely too big to satisfy (W+1)-W == 1
			                              ...*/
	U1 = One / W;
	U2 = Radix * U1;
	printf("Closest relative separation found is U1 = "); printFLOAT("%.7e", U1); printf(" .\n\n");
	printf("Recalculating radix and precision\n ");

	/*save old values*/
	E0 = Radix;
	E1 = U1;
	E9 = U2;
	E3 = Precision;

	X = Four / Three;
	Third = X - One;
	F6 = Half - Third;
	X = F6 + F6;
	X = FABS(X - Third);
	if (X < U2) X = U2;

	/*... now X = (unknown no.) ulps of 1+...*/
	do  {
		U2 = X;
		Y = Half * U2 + ThirtyTwo * U2 * U2;
		Y = One + Y;
		X = Y - One;
		} while ( ! ((U2 <= X) || (X <= Zero)));

	/*... now U2 == 1 ulp of 1 + ... */
	X = Two / Three;
	F6 = X - Half;
	Third = F6 + F6;
	X = Third - Half;
	X = FABS(X + F6);
	if (X < U1) X = U1;

	/*... now  X == (unknown no.) ulps of 1 -... */
	do  {
		U1 = X;
		Y = Half * U1 + ThirtyTwo * U1 * U1;
		Y = Half - Y;
		X = Half + Y;
		Y = Half - X;
		X = Half + Y;
		} while ( ! ((U1 <= X) || (X <= Zero)));
	/*... now U1 == 1 ulp of 1 - ... */
	if (U1 == E1) printf("confirms closest relative separation U1 .\n");
	else  printf("gets better closest relative separation U1 = "), printFLOAT("%.7e", U1), printf(" .\n");
	W = One / U1;
	F9 = (Half - U1) + Half;
	Radix = FLOOR(0.01 + U2 / U1);
	if (Radix == E0) printf("Radix confirmed.\n");
	else  printf("MYSTERY: recalculated Radix = "), printFLOAT("%.7e", Radix), printf(" .\n");
	TstCond (Defect, Radix <= Eight + Eight,
		   "Radix is too big: roundoff problems");
	TstCond (Flaw, (Radix == Two) || (Radix == Ten)
		   || (Radix == One), "Radix is not as good as 2 or 10");
	/*=============================================*/
	Milestone = 20;
	/*=============================================*/
	TstCond (Failure, F9 - Half < Half,
		   "(1-U1)-1/2 < 1/2 is FALSE, prog. fails?");
	X = F9;
	I = 1;
	Y = X - Half;
	Z = Y - Half;
	TstCond (Failure, (X != One)
		   || (Z == Zero), "Comparison is fuzzy,X=1 but X-1/2-1/2 != 0");
	X = One + U2;
	I = 0;
	/*=============================================*/
	Milestone = 25;
	/*=============================================*/
	/*... BMinusU2 = nextafter(Radix, 0) */
	BMinusU2 = Radix - One;
	BMinusU2 = (BMinusU2 - U2) + One;
	/* Purify Integers */
	if (Radix != One)  {
		X = - TwoForty * LOG(U1) / LOG(Radix);
		Y = FLOOR(Half + X);
		if (FABS(X - Y) * Four < One) X = Y;
		Precision = X / TwoForty;
		Y = FLOOR(Half + Precision);
		if (FABS(Precision - Y) * TwoForty < Half) Precision = Y;
		}
	if ((Precision != FLOOR(Precision)) || (Radix == One)) {
		printf("Precision cannot be characterized by an Integer number\n");
		printf("of significant digits but, by itself, this is a minor flaw.\n");
		}
	if (Radix == One)
		printf("logarithmic encoding has precision characterized solely by U1.\n");
	else  printf("The number of significant digits of the Radix is "), printFLOAT("%f", Precision), printf(" .\n");
	assert(Radix == 2);
	assert(__ctfe || Precision == FLOAT.mant_dig);
	TstCond (Serious, U2 * Nine * Nine * TwoForty < One,
		   "Precision worse than 5 decimal figures  ");
	/*=============================================*/
	Milestone = 30;
	/*=============================================*/
	/* Test for extra-precise subepressions */
	X = FABS(((Four / Three - One) - One / Four) * Three - One / Four);
	do  {
		Z2 = X;
		X = (One + (Half * Z2 + ThirtyTwo * Z2 * Z2)) - One;
		} while ( ! ((Z2 <= X) || (X <= Zero)));
	X = Y = Z = FABS((Three / Four - Two / Three) * Three - One / Four);
	do  {
		Z1 = Z;
		Z = (One / Two - ((One / Two - (Half * Z1 + ThirtyTwo * Z1 * Z1))
			+ One / Two)) + One / Two;
		} while ( ! ((Z1 <= Z) || (Z <= Zero)));
	do  {
		do  {
			Y1 = Y;
			Y = (Half - ((Half - (Half * Y1 + ThirtyTwo * Y1 * Y1)) + Half
				)) + Half;
			} while ( ! ((Y1 <= Y) || (Y <= Zero)));
		X1 = X;
		X = ((Half * X1 + ThirtyTwo * X1 * X1) - F9) + F9;
		} while ( ! ((X1 <= X) || (X <= Zero)));
	if ((X1 != Y1) || (X1 != Z1)) {
		BadCond(Serious, "Disagreements among the values X1, Y1, Z1,\n");
		printf("respectively  "); printFLOAT("%.7e", X1); printf(",  "); printFLOAT("%.7e", Y1); printf(",  "); printFLOAT("%.7e", Z1); printf(",\n");
		printf("are symptoms of inconsistencies introduced\n");
		printf("by extra-precise evaluation of arithmetic subexpressions.\n");
		notify("Possibly some part of this");
		if ((X1 == U1) || (Y1 == U1) || (Z1 == U1))  printf(
			"That feature is not tested further by this program.\n") ;
		}
	else  {
		if ((Z1 != U1) || (Z2 != U2)) {
			if ((Z1 >= U1) || (Z2 >= U2)) {
				BadCond(Failure, "");
				notify("Precision");
				printf("\tU1 = "); printFLOAT("%.7e", U1); printf(", Z1 - U1 = "); printFLOAT("%.7e", Z1-U1); printf("\n");
				printf("\tU2 = "); printFLOAT("%.7e", U2); printf(", Z2 - U2 = "); printFLOAT("%.7e", Z2-U2); printf("\n");
				}
			else {
				if ((Z1 <= Zero) || (Z2 <= Zero)) {
					printf("Because of unusual Radix = "); printFLOAT("%f", Radix);
					printf(", or exact rational arithmetic a result\n");
					printf("Z1 = "); printFLOAT("%.7e", Z1); printf(", or Z2 = "); printFLOAT("%.7e", Z2); printf(" ");
					notify("of an\nextra-precision");
					}
				if (Z1 != Z2 || Z1 > Zero) {
					X = Z1 / U1;
					Y = Z2 / U2;
					if (Y > X) X = Y;
					Q = - LOG(X);
					printf("Some subexpressions appear to be calculated extra\n");
					printf("precisely with about "); printFLOAT("%g", Q / LOG(Radix)); printf(" extra B-digits, i.e.\n");
					printf("roughly "); printFLOAT("%g", Q / LOG(Ten)); printf(" extra significant decimals.\n");
					}
				printf("That feature is not tested further by this program.\n");
				}
			}
		}
	Pause();
	/*=============================================*/
	/*SPLIT
	}
#include "paranoia.h"
void part3(){
*/
	Milestone = 35;
	/*=============================================*/
	if (Radix >= Two) {
		X = W / (Radix * Radix);
		Y = X + One;
		Z = Y - X;
		T = Z + U2;
		X = T - Z;
		TstCond (Failure, X == U2,
			"Subtraction is not normalized X=Y,X+Z != Y+Z!");
		if (X == U2) printf(
			"Subtraction appears to be normalized, as it should be.");
		}
	printf("\nChecking for guard digit in *, /, and -.\n");
	Y = F9 * One;
	Z = One * F9;
	X = F9 - Half;
	Y = (Y - Half) - X;
	Z = (Z - Half) - X;
	X = One + U2;
	T = X * Radix;
	R = Radix * X;
	X = T - Radix;
	X = X - Radix * U2;
	T = R - Radix;
	T = T - Radix * U2;
	X = X * (Radix - One);
	T = T * (Radix - One);
	if ((X == Zero) && (Y == Zero) && (Z == Zero) && (T == Zero)) GMult = Yes;
	else {
		GMult = No;
		TstCond (Serious, False,
			"* lacks a Guard Digit, so 1*X != X");
		}
	Z = Radix * U2;
	X = One + Z;
	Y = FABS((X + Z) - X * X) - U2;
	X = One - U2;
	Z = FABS((X - U2) - X * X) - U1;
	TstCond (Failure, (Y <= Zero)
		   && (Z <= Zero), "* gets too many final digits wrong.\n");
	Y = One - U2;
	X = One + U2;
	Z = One / Y;
	Y = Z - X;
	X = One / Three;
	Z = Three / Nine;
	X = X - Z;
	T = Nine / TwentySeven;
	Z = Z - T;
	TstCond(Defect, X == Zero && Y == Zero && Z == Zero,
		"Division lacks a Guard Digit, so error can exceed 1 ulp
or  1/3  and  3/9  and  9/27 may disagree");
	Y = F9 / One;
	X = F9 - Half;
	Y = (Y - Half) - X;
	X = One + U2;
	T = X / One;
	X = T - X;
	if ((X == Zero) && (Y == Zero) && (Z == Zero)) GDiv = Yes;
	else {
		GDiv = No;
		TstCond (Serious, False,
			"Division lacks a Guard Digit, so X/1 != X");
		}
	X = One / (One + U2);
	Y = X - Half - Half;
	TstCond (Serious, Y < Zero,
		   "Computed value of 1/1.000..1 >= 1");
	X = One - U2;
	Y = One + Radix * U2;
	Z = X * Radix;
	T = Y * Radix;
	R = Z / Radix;
	StickyBit = T / Radix;
	X = R - X;
	Y = StickyBit - Y;
	TstCond (Failure, X == Zero && Y == Zero,
			"* and/or / gets too many last digits wrong");
	Y = One - U1;
	X = One - F9;
	Y = One - Y;
	T = Radix - U2;
	Z = Radix - BMinusU2;
	T = Radix - T;
	if ((X == U1) && (Y == U1) && (Z == U2) && (T == U2)) GAddSub = Yes;
	else {
		GAddSub = No;
		TstCond (Serious, False,
			"- lacks Guard Digit, so cancellation is obscured");
		}
	if (F9 != One && F9 - One >= Zero) {
		BadCond(Serious, "comparison alleges  (1-U1) < 1  although\n");
		printf("  subtraction yields  (1-U1) - 1 = 0 , thereby vitiating\n");
		printf("  such precautions against division by zero as\n");
		printf("  ...  if (X == 1.0) {.....} else {.../(X-1.0)...}\n");
		}
	if (GMult == Yes && GDiv == Yes && GAddSub == Yes) printf(
		"     *, /, and - appear to have guard digits, as they should.\n");
	/*=============================================*/
	Milestone = 40;
	/*=============================================*/
	Pause();
	printf("Checking rounding on multiply, divide and add/subtract.\n");
	RMult = Other;
	RDiv = Other;
	RAddSub = Other;
	RadixD2 = Radix / Two;
	A1 = Two;
	Done = False;
	do  {
		AInvrse = Radix;
		do  {
			X = AInvrse;
			AInvrse = AInvrse / A1;
			} while ( ! (FLOOR(AInvrse) != AInvrse));
		Done = (X == One) || (A1 > Three);
		if (! Done) A1 = Nine + One;
		} while ( ! Done);
	if (X == One) A1 = Radix;
	AInvrse = One / A1;
	X = A1;
	Y = AInvrse;
	Done = False;
	do  {
		Z = X * Y - Half;
		TstCond (Failure, Z == Half,
			"X * (1/X) differs from 1");
		Done = X == Radix;
		X = Radix;
		Y = One / X;
		} while ( ! Done);
	Y2 = One + U2;
	Y1 = One - U2;
	X = OneAndHalf - U2;
	Y = OneAndHalf + U2;
	Z = (X - U2) * Y2;
	T = Y * Y1;
	Z = Z - X;
	T = T - X;
	X = X * Y2;
	Y = (Y + U2) * Y1;
	X = X - OneAndHalf;
	Y = Y - OneAndHalf;
	if ((X == Zero) && (Y == Zero) && (Z == Zero) && (T <= Zero)) {
		X = (OneAndHalf + U2) * Y2;
		Y = OneAndHalf - U2 - U2;
		Z = OneAndHalf + U2 + U2;
		T = (OneAndHalf - U2) * Y1;
		X = X - (Z + U2);
		StickyBit = Y * Y1;
		S = Z * Y2;
		T = T - Y;
		Y = (U2 - Y) + StickyBit;
		Z = S - (Z + U2 + U2);
		StickyBit = (Y2 + U2) * Y1;
		Y1 = Y2 * Y1;
		StickyBit = StickyBit - Y2;
		Y1 = Y1 - Half;
		if ((X == Zero) && (Y == Zero) && (Z == Zero) && (T == Zero)
			&& ( StickyBit == Zero) && (Y1 == Half)) {
			RMult = Rounded;
			printf("Multiplication appears to round correctly.\n");
			}
		else	 if ((X + U2 == Zero) && (Y < Zero) && (Z + U2 == Zero)
				&& (T < Zero) && (StickyBit + U2 == Zero)
				&& (Y1 < Half)) {
				RMult = Chopped;
				printf("Multiplication appears to chop.\n");
				}
			else  printf("* is neither chopped nor correctly rounded.\n");
		if ((RMult == Rounded) && (GMult == No)) notify("Multiplication");
		}
	else  printf("* is neither chopped nor correctly rounded.\n");
	/*=============================================*/
	Milestone = 45;
	/*=============================================*/
	Y2 = One + U2;
	Y1 = One - U2;
	Z = OneAndHalf + U2 + U2;
	X = Z / Y2;
	T = OneAndHalf - U2 - U2;
	Y = (T - U2) / Y1;
	Z = (Z + U2) / Y2;
	X = X - OneAndHalf;
	Y = Y - T;
	T = T / Y1;
	Z = Z - (OneAndHalf + U2);
	T = (U2 - OneAndHalf) + T;
	if (! ((X > Zero) || (Y > Zero) || (Z > Zero) || (T > Zero))) {
		X = OneAndHalf / Y2;
		Y = OneAndHalf - U2;
		Z = OneAndHalf + U2;
		X = X - Y;
		T = OneAndHalf / Y1;
		Y = Y / Y1;
		T = T - (Z + U2);
		Y = Y - Z;
		Z = Z / Y2;
		Y1 = (Y2 + U2) / Y2;
		Z = Z - OneAndHalf;
		Y2 = Y1 - Y2;
		Y1 = (F9 - U1) / F9;
		if ((X == Zero) && (Y == Zero) && (Z == Zero) && (T == Zero)
			&& (Y2 == Zero) && (Y2 == Zero)
			&& (Y1 - Half == F9 - Half )) {
			RDiv = Rounded;
			printf("Division appears to round correctly.\n");
			if (GDiv == No) notify("Division");
			}
		else  if ((X < Zero) && (Y < Zero) && (Z < Zero) && (T < Zero)
			&& (Y2 < Zero) && (Y1 - Half < F9 - Half)) {
			RDiv = Chopped;
			printf("Division appears to chop.\n");
			}
		}
	if (RDiv == Other) printf("/ is neither chopped nor correctly rounded.\n");
	BInvrse = One / Radix;
	TstCond (Failure, (BInvrse * Radix - Half == Half),
		   "Radix * ( 1 / Radix ) differs from 1");
	/*=============================================*/
	/*SPLIT
	}
#include "paranoia.h"
void part4(){
*/
	Milestone = 50;
	/*=============================================*/
	TstCond (Failure, ((F9 + U1) - Half == Half)
		   && ((BMinusU2 + U2 ) - One == Radix - One),
		   "Incomplete carry-propagation in Addition");
	X = One - U1 * U1;
	Y = One + U2 * (One - U2);
	Z = F9 - Half;
	X = (X - Half) - Z;
	Y = Y - One;
	if ((X == Zero) && (Y == Zero)) {
		RAddSub = Chopped;
		printf("Add/Subtract appears to be chopped.\n");
		}
	if (GAddSub == Yes) {
		X = (Half + U2) * U2;
		Y = (Half - U2) * U2;
		X = One + X;
		Y = One + Y;
		X = (One + U2) - X;
		Y = One - Y;
		if ((X == Zero) && (Y == Zero)) {
			X = (Half + U2) * U1;
			Y = (Half - U2) * U1;
			X = One - X;
			Y = One - Y;
			X = F9 - X;
			Y = One - Y;
			if ((X == Zero) && (Y == Zero)) {
				RAddSub = Rounded;
				printf("Addition/Subtraction appears to round correctly.\n");
				if (GAddSub == No) notify("Add/Subtract");
				}
			else  printf("Addition/Subtraction neither rounds nor chops.\n");
			}
		else  printf("Addition/Subtraction neither rounds nor chops.\n");
		}
	else  printf("Addition/Subtraction neither rounds nor chops.\n");
	S = One;
	X = One + Half * (One + Half);
	Y = (One + U2) * Half;
	Z = X - Y;
	T = Y - X;
	StickyBit = Z + T;
	if (StickyBit != Zero) {
		S = Zero;
		BadCond(Flaw, "(X - Y) + (Y - X) is non zero!\n");
		}
	StickyBit = Zero;
	if ((GMult == Yes) && (GDiv == Yes) && (GAddSub == Yes)
		&& (RMult == Rounded) && (RDiv == Rounded)
		&& (RAddSub == Rounded) && (FLOOR(RadixD2) == RadixD2)) {
		printf("Checking for sticky bit.\n");
		X = (Half + U1) * U2;
		Y = Half * U2;
		Z = One + Y;
		T = One + X;
		if ((Z - One <= Zero) && (T - One >= U2)) {
			Z = T + Y;
			Y = Z - X;
			if ((Z - T >= U2) && (Y - T == Zero)) {
				X = (Half + U1) * U1;
				Y = Half * U1;
				Z = One - Y;
				T = One - X;
				if ((Z - One == Zero) && (T - F9 == Zero)) {
					Z = (Half - U1) * U1;
					T = F9 - Z;
					Q = F9 - Y;
					if ((T - F9 == Zero) && (F9 - U1 - Q == Zero)) {
						Z = (One + U2) * OneAndHalf;
						T = (OneAndHalf + U2) - Z + U2;
						X = One + Half / Radix;
						Y = One + Radix * U2;
						Z = X * Y;
						if (T == Zero && X + Radix * U2 - Z == Zero) {
							if (Radix != Two) {
								X = Two + U2;
								Y = X / Two;
								if ((Y - One == Zero)) StickyBit = S;
								}
							else  StickyBit = S;
							}
						}
					}
				}
			}
		}
	if (StickyBit == One) printf("Sticky bit apparently used correctly.\n");
	else  printf("Sticky bit used incorrectly or not at all.\n");
	TstCond (Flaw, !(GMult == No || GDiv == No || GAddSub == No ||
			RMult == Other || RDiv == Other || RAddSub == Other),
		"lack(s) of guard digits or failure(s) to correctly round or chop
(noted above) count as one flaw in the final tally below");
	/*=============================================*/
	Milestone = 60;
	/*=============================================*/
	printf("\n");
	printf("Does Multiplication commute?  ");
	printf("Testing on %d random pairs.\n", NoTrials);
	Random9 = SQRT(3.0);
	Random1 = Third;
	I = 1;
	do  {
		X = Random();
		Y = Random();
		Z9 = Y * X;
		Z = X * Y;
		Z9 = Z - Z9;
		I = I + 1;
		} while ( ! ((I > NoTrials) || (Z9 != Zero)));
	if (I == NoTrials) {
		Random1 = One + Half / Three;
		Random2 = (U2 + U1) + One;
		Z = Random1 * Random2;
		Y = Random2 * Random1;
		Z9 = (One + Half / Three) * ((U2 + U1) + One) - (One + Half /
			Three) * ((U2 + U1) + One);
		}
	if (! ((I == NoTrials) || (Z9 == Zero)))
		BadCond(Defect, "X * Y == Y * X trial fails.\n");
	else  printf("     No failures found in %d integer pairs.\n", NoTrials);
	/*=============================================*/
	Milestone = 70;
	/*=============================================*/
	printf("\nRunning test of square root(x).\n");
	TstCond (Failure, (Zero == SQRT(Zero))
		   && (- Zero == SQRT(- Zero))
		   && (One == SQRT(One)), "Square root of 0.0, -0.0 or 1.0 wrong");
	MinSqEr = Zero;
	MaxSqEr = Zero;
	J = Zero;
	X = Radix;
	OneUlp = U2;
	SqXMinX (Serious);
	X = BInvrse;
	OneUlp = BInvrse * U1;
	SqXMinX (Serious);
	X = U1;
	OneUlp = U1 * U1;
	SqXMinX (Serious);
	if (J != Zero) Pause();
	printf("Testing if sqrt(X * X) == X for %d Integers X.\n", NoTrials);
	J = Zero;
	X = Two;
	Y = Radix;
	if ((Radix != One)) do  {
		X = Y;
		Y = Radix * Y;
		} while ( ! ((Y - X >= NoTrials)));
	OneUlp = X * U2;
	I = 1;
	while (I <= NoTrials) {
		X = X + One;
		SqXMinX (Defect);
		if (J > Zero) break;
		I = I + 1;
		}
	printf("Test for sqrt monotonicity.\n");
	I = - 1;
	X = BMinusU2;
	Y = Radix;
	Z = Radix + Radix * U2;
	NotMonot = False;
	Monot = False;
	while ( ! (NotMonot || Monot)) {
		I = I + 1;
		X = SQRT(X);
		Q = SQRT(Y);
		Z = SQRT(Z);
		if ((X > Q) || (Q > Z)) NotMonot = True;
		else {
			Q = FLOOR(Q + Half);
			if (!(I > 0 || Radix == Q * Q)) Monot = True;
			else  if (I > 0) {
			if (I > 1) Monot = True;
			else {
				Y = Y * BInvrse;
				X = Y - U1;
				Z = Y + U1;
				}
			}
			else {
				Y = Q;
				X = Y - U2;
				Z = Y + U2;
				}
			}
		}
	if (Monot) printf("sqrt has passed a test for Monotonicity.\n");
	else {
		BadCond(Defect, "");
		printf("sqrt(X) is non-monotonic for X near "); printFLOAT("%.7e", Y); printf(" .\n");
		}
	/*=============================================*/
	/*SPLIT
	}
#include "paranoia.h"
void part5(){
*/
	Milestone = 80;
	/*=============================================*/
	MinSqEr = MinSqEr + Half;
	MaxSqEr = MaxSqEr - Half;
	Y = (SQRT(One + U2) - One) / U2;
	SqEr = (Y - One) + U2 / Eight;
	if (SqEr > MaxSqEr) MaxSqEr = SqEr;
	SqEr = Y + U2 / Eight;
	if (SqEr < MinSqEr) MinSqEr = SqEr;
	Y = ((SQRT(F9) - U2) - (One - U2)) / U1;
	SqEr = Y + U1 / Eight;
	if (SqEr > MaxSqEr) MaxSqEr = SqEr;
	SqEr = (Y + One) + U1 / Eight;
	if (SqEr < MinSqEr) MinSqEr = SqEr;
	OneUlp = U2;
	X = OneUlp;
	for( Indx = 1; Indx <= 3; ++Indx) {
		Y = SQRT((X + U1 + X) + F9);
		Y = ((Y - U2) - ((One - U2) + X)) / OneUlp;
		Z = ((U1 - X) + F9) * Half * X * X / OneUlp;
		SqEr = (Y + Half) + Z;
		if (SqEr < MinSqEr) MinSqEr = SqEr;
		SqEr = (Y - Half) + Z;
		if (SqEr > MaxSqEr) MaxSqEr = SqEr;
		if (((Indx == 1) || (Indx == 3)))
			X = OneUlp * Sign (X) * FLOOR(Eight / (Nine * SQRT(OneUlp)));
		else {
			OneUlp = U1;
			X = - OneUlp;
			}
		}
	/*=============================================*/
	Milestone = 85;
	/*=============================================*/
	SqRWrng = False;
	Anomaly = False;
	RSqrt = Other; /* ~dgh */
	if (Radix != One) {
		printf("Testing whether sqrt is rounded or chopped.\n");
		D = FLOOR(Half + POW(Radix, One + Precision - FLOOR(Precision)));
	/* ... == Radix^(1 + fract) if (Precision == Integer + fract. */
		X = D / Radix;
		Y = D / A1;
		if ((X != FLOOR(X)) || (Y != FLOOR(Y))) {
			Anomaly = True;
			}
		else {
			X = Zero;
			Z2 = X;
			Y = One;
			Y2 = Y;
			Z1 = Radix - One;
			FourD = Four * D;
			do  {
				if (Y2 > Z2) {
					Q = Radix;
					Y1 = Y;
					do  {
						X1 = FABS(Q + FLOOR(Half - Q / Y1) * Y1);
						Q = Y1;
						Y1 = X1;
						} while ( ! (X1 <= Zero));
					if (Q <= One) {
						Z2 = Y2;
						Z = Y;
						}
					}
				Y = Y + Two;
				X = X + Eight;
				Y2 = Y2 + X;
				if (Y2 >= FourD) Y2 = Y2 - FourD;
				} while ( ! (Y >= D));
			X8 = FourD - Z2;
			Q = (X8 + Z * Z) / FourD;
			X8 = X8 / Eight;
			if (Q != FLOOR(Q)) Anomaly = True;
			else {
				Break = False;
				do  {
					X = Z1 * Z;
					X = X - FLOOR(X / Radix) * Radix;
					if (X == One)
						Break = True;
					else
						 Z1 = Z1 - One;
					} while ( ! (Break || (Z1 <= Zero)));
				if ((Z1 <= Zero) && (! Break)) Anomaly = True;
				else {
					if (Z1 > RadixD2) Z1 = Z1 - Radix;
					do  {
						NewD();
						} while ( ! (U2 * D >= F9));
					if (D * Radix - D != W - D) Anomaly = True;
					else {
						Z2 = D;
						I = 0;
						Y = D + (One + Z) * Half;
						X = D + Z + Q;
						SR3750();
						Y = D + (One - Z) * Half + D;
						X = D - Z + D;
						X = X + Q + X;
						SR3750();
						NewD();
						if (D - Z2 != W - Z2) Anomaly = True;
						else {
							Y = (D - Z2) + (Z2 + (One - Z) * Half);
							X = (D - Z2) + (Z2 - Z + Q);
							SR3750();
							Y = (One + Z) * Half;
							X = Q;
							SR3750();
							if (I == 0) Anomaly = True;
							}
						}
					}
				}
			}
		if ((I == 0) || Anomaly) {
			enum Category = relaxedChecks ? Defect : Failure;
			BadCond(Category, "Anomalous arithmetic with Integer < ");
			printf("Radix^Precision = "); printFLOAT("%.7e", W); printf("\n");
			printf(" fails test whether sqrt rounds or chops.\n");
			SqRWrng = True;
			}
		}
	if (! Anomaly) {
		if (! ((MinSqEr < Zero) || (MaxSqEr > Zero))) {
			RSqrt = Rounded;
			printf("Square root appears to be correctly rounded.\n");
			}
		else  {
			if ((MaxSqEr + U2 > U2 - Half) || (MinSqEr > Half)
				|| (MinSqEr + Radix < Half)) SqRWrng = True;
			else {
				RSqrt = Chopped;
				printf("Square root appears to be chopped.\n");
				}
			}
		}
	if (SqRWrng) {
		printf("Square root is neither chopped nor correctly rounded.\n");
		printf("Observed errors run from "); printFLOAT("%.7e", MinSqEr - Half); printf(" ");
		printf("to "); printFLOAT("%.7e", Half + MaxSqEr); printf(" ulps.\n");
		enum Category = relaxedChecks ? Defect : Serious;
		TstCond (Category, MaxSqEr - MinSqEr < Radix * Radix,
			"sqrt gets too many last digits wrong");
		}
	/*=============================================*/
	Milestone = 90;
	/*=============================================*/
	Pause();
	printf("Testing powers Z^i for small Integers Z and i.\n");
	N = 0;
	/* ... test powers of zero. */
	I = 0;
	Z = -Zero;
	M = 3;
	Break = False;
	do  {
		X = One;
		SR3980();
		if (I <= 10) {
			I = 1023;
			SR3980();
			}
		if (Z == MinusOne) Break = True;
		else {
			Z = MinusOne;
			/* .. if(-1)^N is invalid, replace MinusOne by One. */
			I = - 4;
			}
		} while ( ! Break);
	PrintIfNPositive();
	N1 = N;
	N = 0;
	Z = A1;
	M = cast(int)FLOOR(Two * LOG(W) / LOG(A1));
	Break = False;
	do  {
		X = Z;
		I = 1;
		SR3980();
		if (Z == AInvrse) Break = True;
		else  Z = AInvrse;
		} while ( ! Break);
	/*=============================================*/
		Milestone = 100;
	/*=============================================*/
	/*  Powers of Radix have been tested, */
	/*         next try a few primes     */
	M = NoTrials;
	Z = Three;
	do  {
		X = Z;
		I = 1;
		SR3980();
		do  {
			Z = Z + Two;
			} while ( Three * FLOOR(Z / Three) == Z );
		} while ( Z < Eight * Three );
	if (N > 0) {
		printf("Errors like this may invalidate financial calculations\n");
		printf("\tinvolving interest rates.\n");
		}
	PrintIfNPositive();
	N += N1;
	if (N == 0) printf("... no discrepancies found.\n");
	if (N > 0) Pause();
	else  printf("\n");
	/*=============================================*/
	/*SPLIT
	}
#include "paranoia.h"
void part6(){
*/
	Milestone = 110;
	/*=============================================*/
	printf("Seeking Underflow thresholds UfThold and E0.\n");
	D = U1;
	if (Precision != FLOOR(Precision)) {
		D = BInvrse;
		X = Precision;
		do  {
			D = D * BInvrse;
			X = X - One;
			} while ( X > Zero);
		}
	Y = One;
	Z = D;
	/* ... D is power of 1/Radix < 1. */
	do  {
		C = Y;
		Y = Z;
		Z = Y * Y;
		} while ((Y > Z) && (Z + Z > Z));
	Y = C;
	Z = Y * D;
	do  {
		C = Y;
		Y = Z;
		Z = Y * D;
		} while ((Y > Z) && (Z + Z > Z));
	if (Radix < Two) HInvrse = Two;
	else  HInvrse = Radix;
	H = One / HInvrse;
	/* ... 1/HInvrse == H == Min(1/Radix, 1/2) */
	CInvrse = One / C;
	E0 = C;
	Z = E0 * H;
	/* ...1/Radix^(BIG Integer) << 1 << CInvrse == 1/C */
	do  {
		Y = E0;
		E0 = Z;
		Z = E0 * H;
		} while ((E0 > Z) && (Z + Z > Z));
	UfThold = E0;
	E1 = Zero;
	Q = Zero;
	E9 = U2;
	S = One + E9;
	D = C * S;
	if (D <= C) {
		E9 = Radix * U2;
		S = One + E9;
		D = C * S;
		if (D <= C) {
			BadCond(Failure, "multiplication gets too many last digits wrong.\n");
			Underflow = E0;
			Y1 = Zero;
			PseudoZero = Z;
			Pause();
			}
		}
	else {
		Underflow = D;
		PseudoZero = Underflow * H;
		UfThold = Zero;
		do  {
			Y1 = Underflow;
			Underflow = PseudoZero;
			if (E1 + E1 <= E1) {
				Y2 = Underflow * HInvrse;
				E1 = FABS(Y1 - Y2);
				Q = Y1;
				if ((UfThold == Zero) && (Y1 != Y2)) UfThold = Y1;
				}
			PseudoZero = PseudoZero * H;
			} while ((Underflow > PseudoZero)
				&& (PseudoZero + PseudoZero > PseudoZero));
		}
	/* Comment line 4530 .. 4560 */
	if (PseudoZero != Zero) {
		printf("\n");
		Z = PseudoZero;
	/* ... Test PseudoZero for "phoney- zero" violates */
	/* ... PseudoZero < Underflow or PseudoZero < PseudoZero + PseudoZero
		   ... */
		if (PseudoZero <= Zero) {
			BadCond(Failure, "Positive expressions can underflow to an\n");
			printf("allegedly negative value\n");
			printf("PseudoZero that prints out as: "); printFLOAT("%g", PseudoZero); printf(" .\n");
			X = - PseudoZero;
			if (X <= Zero) {
				printf("But -PseudoZero, which should be\n");
				printf("positive, isn't; it prints out as  "); printFLOAT("%g", X); printf(" .\n");
				}
			}
		else {
			BadCond(Flaw, "Underflow can stick at an allegedly positive\n");
			printf("value PseudoZero that prints out as "); printFLOAT("%g", PseudoZero); printf(" .\n");
			}
		TstPtUf();
		}
	/*=============================================*/
	Milestone = 120;
	/*=============================================*/
	if (CInvrse * Y > CInvrse * Y1) {
		S = H * S;
		E0 = Underflow;
		}
	if (! ((E1 == Zero) || (E1 == E0))) {
		BadCond(Defect, "");
		if (E1 < E0) {
			printf("Products underflow at a higher");
			printf(" threshold than differences.\n");
			if (PseudoZero == Zero)
			E0 = E1;
			}
		else {
			printf("Difference underflows at a higher");
			printf(" threshold than products.\n");
			}
		}
	printf("Smallest strictly positive number found is E0 = "); printFLOAT("%g", E0); printf(" .\n");
	Z = E0;
	TstPtUf();
	Underflow = E0;
	if (N == 1) Underflow = Y;
	I = 4;
	if (E1 == Zero) I = 3;
	if (UfThold == Zero) I = I - 2;
	UfNGrad = True;
	switch (I)  {
		case	 1:
		UfThold = Underflow;
		if ((CInvrse * Q) != ((CInvrse * Y) * S)) {
			UfThold = Y;
			BadCond(Failure, "Either accuracy deteriorates as numbers\n");
			printf("approach a threshold = "); printFLOAT("%.17e", UfThold); printf("\n");
			printf(" coming down from "); printFLOAT("%.17e", C); printf("\n");
			printf(" or else multiplication gets too many last digits wrong.\n");
			}
		Pause();
		break;

		case	 2:
		BadCond(Failure, "Underflow confuses Comparison, which alleges that\n");
		printf("Q == Y while denying that |Q - Y| == 0; these values\n");
		printf("print out as Q = "); printFLOAT("%.17e", Q); printf(", Y = "); printFLOAT("%.17e", Y2); printf(" .\n");
		printf ("|Q - Y| = "); printFLOAT("%.17e", FABS(Q - Y2)); printf(" .\n");
		UfThold = Q;
		break;

		case	 3:
		X = X;
		break;

		case	 4:
		if ((Q == UfThold) && (E1 == E0)
			&& (FABS( UfThold - E1 / E9) <= E1)) {
			UfNGrad = False;
			printf("Underflow is gradual; it incurs Absolute Error =\n");
			printf("(roundoff in UfThold) < E0.\n");
			Y = E0 * CInvrse;
			Y = Y * (OneAndHalf + U2);
			X = CInvrse * (One + U2);
			Y = Y / X;
			IEEE = (Y == E0);
			}
		break;
		default: break;
		}
	if (UfNGrad) {
		printf("\n");
		sigsave = sigfpe;
		if (setjmp(ovfl_buf)) {
			printf("Underflow / UfThold failed!\n");
			R = H + H;
			}
		else  R = SQRT(Underflow / UfThold);
		sigsave = null;
		if (R <= H) {
			Z = R * UfThold;
			X = Z * (One + R * H * (One + H));
			}
		else {
			Z = UfThold;
			X = Z * (One + H * H * (One + H));
			}
		if (! ((X == Z) || (X - Z != Zero))) {
			BadCond(Flaw, "");
			printf("X = "); printFLOAT("%.17e", X); printf("\n\tis not equal to Z = "); printFLOAT("%.17e", Z); printf(" .\n");
			Z9 = X - Z;
			printf("yet X - Z yields "); printFLOAT("%.7e", Z9); printf(" .\n");
			printf("    Should this NOT signal Underflow, ");
			printf("this is a SERIOUS DEFECT\nthat causes ");
			printf("confusion when innocent statements like\n");
			printf("    if (X == Z)  ...  else");
			printf("  ... (f(X) - f(Z)) / (X - Z) ...\n");
			printf("encounter Division by Zero although actually\n");
			sigsave = sigfpe;
			if (setjmp(ovfl_buf)) printf("X / Z fails!\n");
			else  printf("X / Z = 1 + "), printFLOAT("%g", (X / Z - Half) - Half), printf(" .\n");
			sigsave = null;
			}
		}
	printf("The Underflow threshold is "); printFLOAT("%.17e", UfThold); printf(", below which\n");
	printf("calculation may suffer larger Relative error than ");
	printf("merely roundoff.\n");
	Y2 = U1 * U1;
	Y = Y2 * Y2;
	Y2 = Y * U1;
	if (Y2 <= UfThold) {
		if (Y > E0) {
			BadCond(Defect, "");
			I = 5;
			}
		else {
			BadCond(Serious, "");
			I = 4;
			}
		printf("Range is too narrow; U1^%d Underflows.\n", I);
		}
	/*=============================================*/
	/*SPLIT
	}
#include "paranoia.h"
void part7(){
*/
	Milestone = 130;
	/*=============================================*/
	Y = - FLOOR(Half - TwoForty * LOG(UfThold) / LOG(HInvrse)) / TwoForty;
	Y2 = Y + Y;
	printf("Since underflow occurs below the threshold\n");
	printf("UfThold = ("); printFLOAT("%.17e", HInvrse); printf(") ^ ("); printFLOAT("%.17e", Y); printf(")\nonly underflow ");
	printf("should afflict the expression\n\t("); printFLOAT("%.17e", HInvrse); printf(") ^ ("); printFLOAT("%.17e", Y2); printf(");\n");
	printf("actually calculating yields:");
	if (setjmp(ovfl_buf)) {
		sigsave = null;
		BadCond(Serious, "trap on underflow.\n");
		}
	else {
		sigsave = sigfpe;
		V9 = POW(HInvrse, Y2);
		sigsave = null;
		printf(" "); printFLOAT("%.17e", V9); printf(" .\n");
		if (! ((V9 >= Zero) && (V9 <= (Radix + Radix + E9) * UfThold))) {
			BadCond(Serious, "this is not between 0 and underflow\n");
		printf("   threshold = "); printFLOAT("%.17e", UfThold); printf(" .\n");
		}
		else  if (! (V9 > UfThold * (One + E9)))
			printf("This computed value is O.K.\n");
		else {
			BadCond(Defect, "this is not between 0 and underflow\n");
			printf("   threshold = "); printFLOAT("%.17e", UfThold); printf(" .\n");
			}
		}
	/*=============================================*/
	Milestone = 140;
	/*=============================================*/
	printf("\n");
	/* ...calculate Exp2 == exp(2) == 7.389056099... */
	X = Zero;
	I = 2;
	Y = Two * Three;
	Q = Zero;
	N = 0;
	do  {
		Z = X;
		I = I + 1;
		Y = Y / (I + I);
		R = Y + Q;
		X = Z + R;
		Q = (Z - X) + R;
		} while(X > Z);
	Z = (OneAndHalf + One / Eight) + X / (OneAndHalf * ThirtyTwo);
	X = Z * Z;
	Exp2 = X * X;
	X = F9;
	Y = X - U1;
	printf("Testing X^((X + 1) / (X - 1)) vs. exp(2) = "); printFLOAT("%.17e", Exp2); printf(" as X -> 1.\n");
	for(I = 1;;) {
		Z = X - BInvrse;
		Z = (X + One) / (Z - (One - BInvrse));
		Q = POW(X, Z) - Exp2;
		if (FABS(Q) > TwoForty * U2) {
			N = 1;
	 		V9 = (X - BInvrse) - (One - BInvrse);
			BadCond(Defect, "Calculated");
			printf(" "); printFLOAT("%.17e", POW(X, Z)); printf(" for\n");
			printf("\t(1 + ("); printFLOAT("%.17e", V9); printf(") ^ ("); printFLOAT("%.17e", Z); printf(");\n");
			printf("\tdiffers from correct value by "); printFLOAT("%.17e", Q); printf(" .\n");
			printf("\tThis much error may spoil financial\n");
			printf("\tcalculations involving tiny interest rates.\n");
			break;
			}
		else {
			Z = (Y - X) * Two + Y;
			X = Y;
			Y = Z;
			Z = One + (X - F9)*(X - F9);
			if (Z > One && I < NoTrials) I++;
			else  {
				if (X > One) {
					if (N == 0)
					   printf("Accuracy seems adequate.\n");
					break;
					}
				else {
					X = One + U2;
					Y = U2 + U2;
					Y += X;
					I = 1;
					}
				}
			}
		}
	/*=============================================*/
	Milestone = 150;
	/*=============================================*/
	printf("Testing powers Z^Q at four nearly extreme values.\n");
	N = 0;
	Z = A1;
	Q = FLOOR(Half - LOG(C) / LOG(A1));
	Break = False;
	do  {
		X = CInvrse;
		Y = POW(Z, Q);
		IsYeqX();
		Q = - Q;
		X = C;
		Y = POW(Z, Q);
		IsYeqX();
		if (Z < One) Break = True;
		else  Z = AInvrse;
		} while ( ! Break);
	PrintIfNPositive();
	if (N == 0) printf(" ... no discrepancies found.\n");
	printf("\n");

	/*=============================================*/
	Milestone = 160;
	/*=============================================*/
	Pause();
	printf("Searching for Overflow threshold:\n");
	printf("This may generate an error.\n");
	Y = - CInvrse;
	V9 = HInvrse * Y;
	sigsave = sigfpe;
	if (setjmp(ovfl_buf)) { I = 0; V9 = Y; goto  overflow; }
	do {
		V = Y;
		Y = V9;
		V9 = HInvrse * Y;
		} while(V9 < Y);
	I = 1;
overflow:
	sigsave = null;
	Z = V9;
	printf("Can `Z = -Y' overflow?\n");
	printf("Trying it on Y = "); printFLOAT("%.17e", Y); printf(" .\n");
	V9 = - Y;
	V0 = V9;
	if (V - Y == V + V0) printf("Seems O.K.\n");
	else {
		printf("finds a ");
		BadCond(Flaw, "-(-Y) differs from Y.\n");
		}
	if (Z != Y) {
		BadCond(Serious, "");
		printf("overflow past "); printFLOAT("%.17e", Y); printf("\n\tshrinks to "); printFLOAT("%.17e", Z); printf(" .\n");
		}
	if (I) {
		Y = V * (HInvrse * U2 - HInvrse);
		Z = Y + ((One - HInvrse) * U2) * V;
		if (Z < V0) Y = Z;
		if (Y < V0) V = Y;
		if (V0 - V < V0) V = V0;
		}
	else {
		V = Y * (HInvrse * U2 - HInvrse);
		V = V + ((One - HInvrse) * U2) * Y;
		}
	printf("Overflow threshold is V  = "); printFLOAT("%.17e", V); printf(" .\n");
	if (I) printf("Overflow saturates at V0 = "), printFLOAT("%.17e", V0), printf(" .\n");
	else  printf("There is no saturation value because the system traps on overflow.\n");
	V9 = V * One;
	printf("No Overflow should be signaled for V * 1 = "); printFLOAT("%.17e", V9); printf("\n");
	V9 = V / One;
	printf("                           nor for V / 1 = "); printFLOAT("%.17e", V9); printf(" .\n");
	printf("Any overflow signal separating this * from the one\n");
	printf("above is a DEFECT.\n");
	/*=============================================*/
	Milestone = 170;
	/*=============================================*/
	if (!(-V < V && -V0 < V0 && -UfThold < V && UfThold < V)) {
		BadCond(Failure, "Comparisons involving ");
		printf("+-"); printFLOAT("%g", V); printf(", +-"); printFLOAT("%g", V0);
        printf("\nand +-"); printFLOAT("%g", UfThold); printf(" are confused by Overflow.");
		}
	/*=============================================*/
	Milestone = 175;
	/*=============================================*/
	printf("\n");
	for(Indx = 1; Indx <= 3; ++Indx) {
		switch (Indx)  {
			case  1: Z = UfThold; break;
			case  2: Z = E0; break;
			case  3: Z = PseudoZero; break;
			default: break;
			}
		if (Z != Zero) {
			V9 = SQRT(Z);
			Y = V9 * V9;
			if (Y / (One - Radix * E9) < Z
			   || Y > (One + Radix * E9) * Z) { /* dgh: + E9 --> * E9 */
				if (V9 > U1) BadCond(Serious, "");
				else  BadCond(Defect, "");
				printf("Comparison alleges that what prints as Z = "); printFLOAT("%.17e", Z);
				printf(" is too far from sqrt(Z) ^ 2 = "); printFLOAT("%.17e", Y); printf(" .\n");
				}
			}
		}
	/*=============================================*/
	Milestone = 180;
	/*=============================================*/
	for(Indx = 1; Indx <= 2; ++Indx) {
		if (Indx == 1) Z = V;
		else  Z = V0;
		V9 = SQRT(Z);
		X = (One - Radix * E9) * V9;
		V9 = V9 * X;
		if (((V9 < (One - Two * Radix * E9) * Z) || (V9 > Z))) {
			Y = V9;
			if (X < W) BadCond(Serious, "");
			else  BadCond(Defect, "");
			printf("Comparison alleges that Z = "); printFLOAT("%.17e", Z);
			printf(" is too far from sqrt(Z) ^ 2 ("); printFLOAT("%.17e", Y); printf(") .\n");
			}
		}
	/*=============================================*/
	/*SPLIT
	}
#include "paranoia.h"
int part8(){
*/
	Milestone = 190;
	/*=============================================*/
	Pause();
	X = UfThold * V;
	Y = Radix * Radix;
	if (X*Y < One || X > Y) {
		if (X * Y < U1 || X > Y/U1) BadCond(Defect, "Badly");
		else  BadCond(Flaw, "");

		printf(" unbalanced range; UfThold * V = "); printFLOAT("%.17e", X);
		printf("\n\tis too far from 1.\n\n");
		}
	/*=============================================*/
	Milestone = 200;
	/*=============================================*/
	for (Indx = 1; Indx <= 5; ++Indx)  {
		X = F9;
		switch (Indx)  {
			case  2: X = One + U2; break;
			case  3: X = V; break;
			case  4: X = UfThold; break;
			case  5: X = Radix; break;
			default: break;
			}
		Y = X;
		sigsave = sigfpe;
		if (setjmp(ovfl_buf))
			printf("  X / X  traps when X = "), printFLOAT("%g", X), printf("\n");
		else {
			V9 = (Y / X - Half) - Half;
			if (V9 == Zero) continue;
			if (V9 == - U1 && Indx < 5) BadCond(Flaw, "");
			else  BadCond(Serious, "");
			printf("  X / X differs from 1 when X = "); printFLOAT("%.17e", X); printf("\n");
			printf("  instead, X / X - 1/2 - 1/2 = "); printFLOAT("%.17e", V9); printf(" .\n");
			}
		sigsave = null;
		}
	/*=============================================*/
	Milestone = 210;
	/*=============================================*/
	MyZero = Zero;
	printf("\n");
	printf("What message and/or values does Division by Zero produce?\n") ;
version(NOPAUSE) {
	ch[0] = 'y';
} else {
	printf("This can interupt your program.  You can ");
	printf("skip this part if you wish.\n");
	printf("Do you wish to compute 1 / 0? ");
	fflush(stdout);
	read (KEYBOARD, ch, 8);
}
	if ((ch[0] == 'Y') || (ch[0] == 'y')) {
		sigsave = sigfpe;
		printf("    Trying to compute 1 / 0 produces ...");
		if (!setjmp(ovfl_buf)) printf("  "), printFLOAT("%.7e", One / MyZero), printf(" .\n");
		sigsave = null;
		}
	else  printf("O.K.\n");
version(NOPAUSE) {} else {
	printf("\nDo you wish to compute 0 / 0? ");
	fflush(stdout);
	read (KEYBOARD, ch, 80);
}
	if ((ch[0] == 'Y') || (ch[0] == 'y')) {
		sigsave = sigfpe;
		printf("\n    Trying to compute 0 / 0 produces ...");
		if (!setjmp(ovfl_buf)) printf("  "), printFLOAT("%.7e", Zero / MyZero), printf(" .\n");
		sigsave = null;
		}
	else  printf("O.K.\n");

	/*=============================================*/
	Milestone = 220;
	/*=============================================*/
	Pause();
	printf("\n");
	{
		static const CHARP[4]msg = [
			"FAILUREs  encountered =",
			"SERIOUS DEFECTs  discovered =",
			"DEFECTs  discovered =",
			"FLAWs  discovered =" ];
		int  i;
		for(i = 0; i < 4; i++) if (ErrCnt[i])
			printf("The number of  %-29s %d.\n",
				msg[i], ErrCnt[i]);
		}
	printf("\n");
	if ((ErrCnt[Failure] + ErrCnt[Serious] + ErrCnt[Defect]
			+ ErrCnt[Flaw]) > 0) {
		if ((ErrCnt[Failure] + ErrCnt[Serious] + ErrCnt[
			Defect] == 0) && (ErrCnt[Flaw] > 0)) {
			printf("The arithmetic diagnosed seems ");
			printf("Satisfactory though flawed.\n");
			}
		if ((ErrCnt[Failure] + ErrCnt[Serious] == 0)
			&& ( ErrCnt[Defect] > 0)) {
			printf("The arithmetic diagnosed may be Acceptable\n");
			printf("despite inconvenient Defects.\n");
			}
		if ((ErrCnt[Failure] + ErrCnt[Serious]) > 0) {
			printf("The arithmetic diagnosed has ");
			printf("unacceptable Serious Defects.\n");
			}
		if (ErrCnt[Failure] > 0) {
			printf("Potentially fatal FAILURE may have spoiled this");
			printf(" program's subsequent diagnoses.\n");
			}
		}
	else {
		printf("No failures, defects nor flaws have been discovered.\n");
		if (! ((RMult == Rounded) && (RDiv == Rounded)
			&& (RAddSub == Rounded) && (RSqrt == Rounded)))
			printf("The arithmetic diagnosed seems Satisfactory.\n");
		else {
			if (StickyBit >= One &&
				(Radix - Two) * (Radix - Nine - One) == Zero) {
				printf("Rounding appears to conform to ");
				printf("the proposed IEEE standard P");
				if ((Radix == Two) &&
					 ((Precision - Four * Three * Two) *
					  ( Precision - TwentySeven -
					   TwentySeven + One) == Zero))
					printf("754");
				else  printf("854");
				if (IEEE) printf(".\n");
				else {
					printf(",\nexcept for possibly Double Rounding");
					printf(" during Gradual Underflow.\n");
					}
				}
			printf("The arithmetic diagnosed appears to be Excellent!\n");
			}
		}
	if (fpecount)
		printf("\nA total of %d floating point exceptions were registered.\n",
			fpecount);
	printf("END OF TEST.\n");
	// allow Flaws (and Defects for relaxed checks)
	int errors = ErrCnt[Failure] + ErrCnt[Serious];
	if (!relaxedChecks)
		errors += ErrCnt[Defect];
	if (__ctfe)
		return 10000 * ErrCnt[Failure] + ErrCnt[Serious] * 100 + ErrCnt[Defect] + ErrCnt[Flaw];
	return errors;
	}

/*SPLIT subs.c
#include "paranoia.h"
*/

 FLOAT
 Sign (FP  X)


{ return  toFLOAT(X >= 0. ? 1.0 : -1.0); }

 void
 Pause()
{
version(NOPAUSE) {} else {
	char[8]  ch;

	printf("\nTo continue, press RETURN");
	fflush(stdout);
	read(KEYBOARD, ch, 8);
}
	printf("\nDiagnosis resumes after milestone Number %d", Milestone);
	printf("          Page: %d\n\n", PageNo);
	++Milestone;
	++PageNo;
	}

 void
 TstCond (INT  K, INT  Valid, CHARP  T)



{ if (! Valid) { BadCond(K,T); printf(".\n"); } }

 void
 BadCond(INT  K, CHARP  T)



{
	static const string[4]msg = [ "FAILURE", "SERIOUS DEFECT", "DEFECT", "FLAW" ];

	ErrCnt [K] = ErrCnt [K] + 1;
	printf("%s:  %s", msg[K].ptr, T);
	if (__ctfe)
		assert(K >= 2, msg[K]);
	}


 FLOAT
 Random()
/*  Random computes
     X = (Random1 + Random9)^5
     Random1 = X - FLOOR(X) + 0.000005 * X;
   and returns the new value of Random1
*/
{
	FLOAT  X, Y;

	X = Random1 + Random9;
	Y = X * X;
	Y = Y * Y;
	X = X * Y;
	Y = X - FLOOR(X);
	Random1 = Y + X * 0.000005;
	return  Random1;
	}

 void
 SqXMinX (INT  ErrKind)


{
	FLOAT  XA, XB;

	XB = X * BInvrse;
	XA = X - XB;
	SqEr = ((SQRT(X * X) - XB) - XA) / OneUlp;
	if (SqEr != Zero) {
		if (SqEr < MinSqEr) MinSqEr = SqEr;
		if (SqEr > MaxSqEr) MaxSqEr = SqEr;
		J = J + 1.0;
		BadCond(ErrKind, "\n");
		printf("sqrt( "); printFLOAT("%.17e", X * X); printf(") - "); printFLOAT("%.17e", X);
        printf("  = "); printFLOAT("%.17e", OneUlp * SqEr); printf("\n");
		printf("\tinstead of correct value 0 .\n");
		}
	}

 void
 NewD()
{
	X = Z1 * Q;
	X = FLOOR(Half - X / Radix) * Radix + X;
	Q = (Q - X * Z) / Radix + X * X * (D / Radix);
	Z = Z - Two * X * D;
	if (Z <= Zero) {
		Z = - Z;
		Z1 = - Z1;
		}
	D = Radix * D;
	}

 void
 SR3750()
{
	if (! ((X - Radix < Z2 - Radix) || (X - Z2 > W - Z2))) {
		I = I + 1;
		X2 = SQRT(X * D);
		Y2 = (X2 - Z2) - (Y - Z2);
		X2 = X8 / (Y - Half);
		X2 = X2 - Half * X2 * X2;
		SqEr = (Y2 + Half) + (Half - X2);
		if (SqEr < MinSqEr) MinSqEr = SqEr;
		SqEr = Y2 - X2;
		if (SqEr > MaxSqEr) MaxSqEr = SqEr;
		}
	}

 void
 IsYeqX()
{
	if (Y != X) {
		if (N <= 0) {
			if (Z == Zero && Q <= Zero)
				printf("WARNING:  computing\n");
			else  BadCond(Defect, "computing\n");
			printf("\t("); printFLOAT("%.17e", Z); printf(") ^ ("); printFLOAT("%.17e", Q); printf(")\n");
			printf("\tyielded "); printFLOAT("%.17e", Y); printf(";\n");
			printf("\twhich compared unequal to correct "); printFLOAT("%.17e", X); printf(" ;\n");
			printf("\t\tthey differ by "); printFLOAT("%.17e", Y - X); printf(" .\n");
			}
		N = N + 1; /* ... count discrepancies. */
		}
	}

 void
 SR3980()
{
	do {
		Q = toFLOAT(I);
		Y = POW(Z, Q);
		IsYeqX();
		if (++I > M) break;
		X = Z * X;
		} while ( X < W );
	}

 void
 PrintIfNPositive()
{
	if (N > 0) printf("Similar discrepancies have occurred %d times.\n", N);
	}

 void
 TstPtUf()
{
	N = 0;
	if (Z != Zero) {
		printf("Since comparison denies Z = 0, evaluating ");
		printf("(Z + Z) / Z should be safe.\n");
		sigsave = sigfpe;
		if (setjmp(ovfl_buf)) goto  very_serious;
		Q9 = (Z + Z) / Z;
		printf("What the machine gets for (Z + Z) / Z is  "); printFLOAT("%.17e", Q9); printf(" .\n");
		if (FABS(Q9 - Two) < Radix * U2) {
			printf("This is O.K., provided Over/Underflow");
			printf(" has NOT just been signaled.\n");
			}
		else {
			if ((Q9 < One) || (Q9 > Two)) {
very_serious:
				N = 1;
				ErrCnt [Serious] = ErrCnt [Serious] + 1;
				printf("This is a VERY SERIOUS DEFECT!\n");
				}
			else {
				N = 1;
				ErrCnt [Defect] = ErrCnt [Defect] + 1;
				printf("This is a DEFECT!\n");
				}
			}
		sigsave = null;
		V9 = Z * One;
		Random1 = V9;
		V9 = One * Z;
		Random2 = V9;
		V9 = Z / One;
		if ((Z == Random1) && (Z == Random2) && (Z == V9)) {
			if (N > 0) Pause();
			}
		else {
			N = 1;
			BadCond(Defect, "What prints as Z = ");
			printf(""); printFLOAT("%.17e", Z); printf("\n\tcompares different from  ");
			if (Z != Random1) printf("Z * 1 = "), printFLOAT("%.17e", Random1), printf(" ");
			if (! ((Z == Random2)
				|| (Random2 == Random1)))
				printf("1 * Z == "), printFLOAT("%g", Random2), printf("\n", Random2);
			if (! (Z == V9)) printf("Z / 1 = "), printFLOAT("%.17e", V9), printf("\n");
			if (Random2 != Random1) {
				ErrCnt [Defect] = ErrCnt [Defect] + 1;
				BadCond(Defect, "Multiplication does not commute!\n");
				printf("\tComparison alleges that 1 * Z = "); printFLOAT("%.17e", Random2); printf("\n");
				printf("\tdiffers from Z * 1 = "); printFLOAT("%.17e", Random1); printf("\n");
				}
			Pause();
			}
		}
	}

 void
 notify(CHARP  s)


{
	printf("%s test appears to be inconsistent...\n", s);
	printf("   PLEASE NOTIFY KARPINKSI!\n");
	}

/*SPLIT msgs.c
#include "paranoia.h"
*/

 void
 msglist(CHARPP  s)


{ while(*s) printf("%s\n", *s++); }

 void
 Instructions()
{
  static  CHARP[10]instr = [
	"Lest this program stop prematurely, i.e. before displaying\n",
	"    `END OF TEST',\n",
	"try to persuade the computer NOT to terminate execution when an",
	"error like Over/Underflow or Division by Zero occurs, but rather",
	"to persevere with a surrogate value after, perhaps, displaying some",
	"warning.  If persuasion avails naught, don't despair but run this",
	"program anyway to see how many milestones it passes, and then",
	"amend it to make further progress.\n",
	"Answer questions with Y, y, N or n (unless otherwise indicated).\n",
	null];

	if (!__ctfe) msglist(instr.ptr);
	}

 void
 Heading()
{
  static  CHARP[20]head = [
	"Users are invited to help debug and augment this program so it will",
	"cope with unanticipated and newly uncovered arithmetic pathologies.\n",
	"Please send suggestions and interesting results to",
	"\tRichard Karpinski",
	"\tComputer Center U-76",
	"\tUniversity of California",
	"\tSan Francisco, CA 94143-0704, USA\n",
	"In doing so, please include the following information:",
//#if Single
//	"\tPrecision:\tsingle;",
//#else
	"\tPrecision:\tdouble;",
//#endif
	"\tVersion:\t10 February 1989;",
	"\tComputer:\n",
	"\tCompiler:\n",
	"\tOptimization level:\n",
	"\tOther relevant compiler options:",
	null];

	if (!__ctfe) msglist(head.ptr);
	}

 void
 Characteristics()
{
	static  CHARP[20]chars = [
	 "Running this program should reveal these characteristics:",
	"     Radix = 1, 2, 4, 8, 10, 16, 100, 256 ...",
	"     Precision = number of significant digits carried.",
	"     U2 = Radix/Radix^Precision = One Ulp",
	"\t(OneUlpnit in the Last Place) of 1.000xxx .",
	"     U1 = 1/Radix^Precision = One Ulp of numbers a little less than 1.0 .",
	"     Adequacy of guard digits for Mult., Div. and Subt.",
	"     Whether arithmetic is chopped, correctly rounded, or something else",
	"\tfor Mult., Div., Add/Subt. and Sqrt.",
	"     Whether a Sticky Bit used correctly for rounding.",
	"     UnderflowThreshold = an underflow threshold.",
	"     E0 and PseudoZero tell whether underflow is abrupt, gradual, or fuzzy.",
	"     V = an overflow threshold, roughly.",
	"     V0  tells, roughly, whether  Infinity  is represented.",
	"     Comparisions are checked for consistency with subtraction",
	"\tand for contamination with pseudo-zeros.",
	"     Sqrt is tested.  Y^X is not tested.",
	"     Extra-precise subexpressions are revealed but NOT YET tested.",
	"     Decimal-Binary conversion is NOT YET tested for accuracy.",
	 null];

	if (!__ctfe) msglist(chars.ptr);
	}

 void
 History()
{ /* History */
 /* Converted from Brian Wichmann's Pascal version to C by Thos Sumner,
	with further massaging by David M. Gay. */

  static  CHARP[20]hist = [
	"The program attempts to discriminate among",
	"   FLAWs, like lack of a sticky bit,",
	"   Serious DEFECTs, like lack of a guard digit, and",
	"   FAILUREs, like 2+2 == 5 .",
	"Failures may confound subsequent diagnoses.\n",
	"The diagnostic capabilities of this program go beyond an earlier",
	"program called `MACHAR', which can be found at the end of the",
	"book  `Software Manual for the Elementary Functions' (1980) by",
	"W. J. Cody and W. Waite. Although both programs try to discover",
	"the Radix, Precision and range (over/underflow thresholds)",
	"of the arithmetic, this program tries to cope with a wider variety",
	"of pathologies, and to say how well the arithmetic is implemented.",
	"\nThe program is based upon a conventional radix representation for",
	"floating-point numbers, but also allows logarithmic encoding",
	"as used by certain early WANG machines.\n",
	"BASIC version of this program (C) 1983 by Prof. W. M. Kahan;",
	"see source comments for more history.",
	null];

	if (!__ctfe) msglist(hist.ptr);
	}

} // struct Paranoia

version(CTFE)
{
	int printf(T...)(const(char)* fmt, T) { return 0; }
	enum errors = Paranoia().main();
	enum failures = errors / 10000;
	enum serious  = (errors % 10000) / 100;
	enum defects  = errors % 100;
	pragma(msg, failures.stringof ~ " failures");
	pragma(msg, serious.stringof ~ " serious defects");
	pragma(msg, defects.stringof ~ " defects/flaws");
	static assert(failures < 100, "Paranoia has faliures/serious defects failures for CTFE " ~ FLOAT.stringof);
}
else
{
	int main()
	{
		Paranoia test;
		return test.main();
	}
}

