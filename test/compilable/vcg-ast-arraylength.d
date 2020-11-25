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
}
