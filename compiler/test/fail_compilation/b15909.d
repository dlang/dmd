/* TEST_OUTPUT:
---
fail_compilation/b15909.d(14): Error: duplicate `case 'a'` in `switch` statement
        case 'a':
        ^
---
*/

void main()
{
    switch ('a')
    {
        case 'a':
        case 'a':
            break;
    }
}
