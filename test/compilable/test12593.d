int[R] aa;  // Place before the declaration of key struct

struct R
{
    int opCmp(ref const R) const { return 0; }
}

void main()
{}
