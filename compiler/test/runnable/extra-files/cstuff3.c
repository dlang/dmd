
/* Use 'gcc -E runnable/extra-files/cstuff3.c >runnable/cstuff3.i' to
 *   update runnable test!
 */
#include <stdbool.h>

int printf(const char *, ...);
void exit(int);

bool useBoolAnd(bool a, bool b)
{
	return a && b;
}

bool useBoolOr(bool a, bool b)
{
	return a || b;
}

bool useBoolXor(bool a, bool b)
{
	return a != b;
}

/*********************************/

int main()
{
	bool baf, bat;
	bat = useBoolAnd( true, true );
	if ( bat != true ) { printf("error 1"); exit(1); }
	baf = useBoolAnd( true, false );
	if ( baf == true ) { printf("error 1a"); exit(1); }
	baf = useBoolAnd( false, true );
	if ( baf == true ) { printf("error 1b"); exit(1); }
	baf = useBoolAnd( false, false );
	if ( baf == true ) { printf("error 1c"); exit(1); }

	bool bbf, bbt;
	bbt = useBoolOr( true, true );
	if ( bbt != true ) { printf("error 2a"); exit(1); }
	bbt = useBoolOr( true, false );
	if ( bbt != true ) { printf("error 2b"); exit(1); }
	bbt = useBoolOr( false, true );
	if ( bbt != true ) { printf("error 2c"); exit(1); }
	bbf = useBoolOr( false, false );
	if ( bbf != false ) { printf("error 2"); exit(1); }

	bool bcf, bct;
	bct = useBoolXor( true, false );
	if ( bct != true ) { printf("error 3a"); exit(1); }
	bct = useBoolXor( false, true );
	if ( bct == false ) { printf("error 3b"); exit(1); }

	bcf = useBoolXor( true, true );
	if ( bcf != false ) { printf("error 3c"); exit(1); }
	bcf = useBoolXor( false, false );
	if ( bcf == true ) { printf("error 3d"); exit(1); }

    return 0;
}

