module vcg_ast_arraylength;
// REQUIRED_ARGS: -vcg-ast -o-
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/vcg-ast-arraylength-postscript.sh

void main()
{
	int[] arr = [1, 2, 3];

	// may use runtime call
	arr.length = 100;

	// should convert to arr = arr[0 .. 0];
	arr.length = 0;

    // https://issues.dlang.org/show_bug.cgi?id=21678
    int[] f;
    int[] a;

    a.length = f.length = 0;
    const x = 0;
    a.length = f.length = x;

    static assert(is(typeof(a.length = 0) == size_t));
    static assert(is(typeof(a.length = f.length = 0) == size_t));
}
