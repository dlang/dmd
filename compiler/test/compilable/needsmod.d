// ARG_SETS: -i
// ARG_SETS: -i=.
// ARG_SETS: -i=imports
// ARG_SETS: -i=imports.foofunc
// PERMUTE_ARGS:
// LINK:
import imports.foofunc;
void main()
{
    foo();
}
