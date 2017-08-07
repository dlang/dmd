// PERMUTE_ARGS:
// REQUIRED_ARGS: -deps=${RESULTS_DIR}/compilable/rdeps7016.deps
// POST_SCRIPT: compilable/extra-files/rdepsOutput.sh 
// EXTRA_SOURCES: extra-files/rdeps7016a.d extra-files/rdeps7016b.d

module rdeps7016;
import rdeps7016a;

void main()
{
    f();
}
