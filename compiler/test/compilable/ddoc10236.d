// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -wi -o-

/*
TEST_OUTPUT:
---
compilable/ddoc10236.d(45): Warning: Ddoc: parameter count mismatch, expected 2, got 1
void foo_count_mismatch(int x, int y)	// Warning: Ddoc: parameter count mismatch
     ^
compilable/ddoc10236.d(57): Warning: Ddoc: function declaration has no parameter 'y'
void foo_no_param_y(int x, int z)		// Warning: Ddoc: function declaration has no parameter 'y'
     ^
compilable/ddoc10236.d(69): Warning: Ddoc: function declaration has no parameter 'y'
void foo_count_mismatch_no_param_y(int x)
     ^
compilable/ddoc10236.d(69): Warning: Ddoc: parameter count mismatch, expected 1, got 2
void foo_count_mismatch_no_param_y(int x)
     ^
compilable/ddoc10236.d(81): Warning: Ddoc: parameter count mismatch, expected 2, got 0
void foo_count_mismatch_wrong_format(int x, int y)
     ^
compilable/ddoc10236.d(81):        Note that the format is `param = description`
---
*/

/***********************************
 * foo_good does this.
 * Params:
 *	x =	is for this
 *		and not for that
 *	y =	is for that
 */

void foo_good(int x, int y)
{
}

/***********************************
 * foo_count_mismatch does this.
 * Params:
 *	x =	is for this
 *		and not for that
 */

void foo_count_mismatch(int x, int y)	// Warning: Ddoc: parameter count mismatch
{
}

/***********************************
 * foo_no_param_y does this.
 * Params:
 *	x =	is for this
 *		and not for that
 *	y =	is for that
 */

void foo_no_param_y(int x, int z)		// Warning: Ddoc: function declaration has no parameter 'y'
{
}

/***********************************
 * foo_count_mismatch_no_param_y does this.
 * Params:
 *	x =	is for this
 *		and not for that
 *	y =	is for that
 */

void foo_count_mismatch_no_param_y(int x)
{
}

/***********************************
 * foo_count_mismatch_wrong_format does this.
 * Params:
 *	x :	is for this
 *		and not for that
 *	y :	is for that
 */

void foo_count_mismatch_wrong_format(int x, int y)
{
}
