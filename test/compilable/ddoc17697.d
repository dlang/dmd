// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 17697

/***
 * See:
 *    http://www.fooa.com/test1
 *    http://www.fooa.com/_test1
 *    https://www.foob.com/test1
 *    $(LINK http://www.fooc.com/test1)
 *    $(LINK2 http://www.food.com/test1, test1)
 */

module test1;

int a;
