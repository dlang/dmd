// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh
// EXTRA_SOURCES: extra-files/ddoc_minimal.ddoc

module test17521;

///
class C1
{/// abc
/// def
int a; }

///
class C2
{/** abc
def
*/
int a; }
