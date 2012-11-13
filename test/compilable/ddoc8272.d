// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 8272

module ddoc8272;

/**
	$(MACRO_A MACRO_B, $(MACRO_D))$(BR)
	A[$(MACRO_B $(MACRO_C $(MACRO_D)))]$(BR)
	A[B{$(MACRO_C $(MACRO_D))}]$(BR)
	A[B{C($(MACRO_D))}]$(BR)
Macros:
	MACRO_A = A[$($1 $(MACRO_C $2))]
	MACRO_B = B{$0}
	MACRO_C = C($0)
	MACRO_D = D
*/
void ddoc8272()
{
}
