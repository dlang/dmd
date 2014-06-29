// REQUIRED_ARGS: -profile

void main() nothrow
{ asm { nop; } } // Error: asm statements are assumed to throw
