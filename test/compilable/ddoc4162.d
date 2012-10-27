// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 4162

///
interface A
{
	///
	static void staticHello() { }

	///
	final void hello() { }
}

void main()
{
}
