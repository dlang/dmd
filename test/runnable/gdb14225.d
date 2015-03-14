/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b 17
r
echo RESULT=
p lok
---
GDB_MATCH: RESULT=.*Something
*/
void main()
{
    string lok = "Something";
    auto chars = "Anything".dup;
    // BP
}
