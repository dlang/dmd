//               ICE WITH PATCHES
// =========================================================


/* 1358. Assertion failure: '0' on line 1548 in file '..\root\root.c'
This one is trivial.
PATCH(lexer.c, Lexer::escapeSequence()).
--- lexer.c	(revision 24)
+++ lexer.c	(working copy)
@@ -1281,8 +1281,10 @@
 			    break;
 			}
 		    }
-		    if (ndigits != 2 && !utf_isValidDchar(v))
+			if (ndigits != 2 && !utf_isValidDchar(v)) {
 			error("invalid UTF character \\U%08x", v);
+			v = 0; // prevent ICE
+			}
 		    c = v;
 		}
 		else

*/
auto bla = "\U80000000";


/* 854 VOTE PATCH (=2863, =2251?) Assertion failure: '0' on line 935 in file 'glue.c'
I haven't checked this patch myself.
--- dmd/func.c	2009-03-05 01:56:46.000000000 +0100
+++ dmd-fixed/func.c	2009-03-30 00:39:41.000000000 +0200
@@ -756,6 +756,27 @@
 	    }
 	}
 
+	if (f->parameters)
+	{
+	    for (size_t i = 0; i < Argument::dim(f->parameters); i++)
+	    {
+		Argument *arg = (Argument *)Argument::getNth(f->parameters, i);
+		Type* nw = arg->type->semantic(0, sc);
+		if (arg->type != nw) {
+		    arg->type = nw;
+		    // Examine this index again.
+		    // This is important if it turned into a tuple.
+		    // In particular, the empty tuple should be handled or the
+		    // next parameter will be skipped.
+		    // FIXME: Maybe we only need to do this for tuples,
+		    //        and can add tuple.length after decrement?
+		    i--;
+		}
+	    }
+	    // update nparams to include expanded tuples
+	    nparams = Argument::dim(f->parameters);
+	}
+
 	// Propagate storage class from tuple parameters to their element-parameters.
 	if (f->parameters)
 	{
*/
template Foo(T...) {
    alias T Foo;
}
void main() {
    auto y = (Foo!(int) x){ return 0; };
}

// 2603. D1+D2. Internal error: ..\backend\cgcs.c 358
/* PATCH: elem *MinExp::toElem(IRState *irs)
just copy code from AddExp::toElem, changing OPadd into OPmin.
*/
void main() {
   auto c = [1,2,3]-[1,2,3];
}
// this variation is wrong code on D2, ICE ..\ztc\cgcs.c 358 on D1.
void main() {
   string c = "a" - "b";
}

// ========= Patches for ICE involving is() expressions

/* 1524 PATCH Assertion failure: '0' on line 863 in file 'constfold.c'
constfold.c
@@ -845,9 +845,9 @@
     Loc loc = e1->loc;
     int cmp;
 
-    if (e1->op == TOKnull && e2->op == TOKnull)
+    if (e1->op == TOKnull || e2->op == TOKnull)
     {
-	cmp = 1;
+		cmp = (e1->op == TOKnull && e2->op == TOKnull) ? 1 : 0;
     }
     else if (e1->op == TOKsymoff && e2->op == TOKsymoff)
     {
*/
bool isNull(string str) {
        return str is null;
}
const bool test = isNull("hello!");

/* 2843 Assertion failure: '0' on line 863 in file 'constfold.c'
PATCH: constfold.c, line 861:
OLD:
        }else
        assert(0);
NEW:
        }else if (e1->isConst() && e2->isConst()) {
        // Comparing a SymExp with a literal, eg typeid(int) is 7.1;
           cmp=0; // An error has already occured. Prevent an ICE.
        }else
        assert(0);
*/        
bool b = 1 is typeid(int);


