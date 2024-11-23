/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/fail11562.d(23): Error: cannot `goto` in or out of `finally` block
    if (b) goto label;
           ^
fail_compilation/fail11562.d(44): Error: cannot `goto` in or out of `finally` block
    if (b) goto label;
           ^
fail_compilation/fail11562.d(56): Error: cannot `goto` in or out of `finally` block
    if (b) goto label;
           ^
fail_compilation/fail11562.d(71): Error: cannot `goto` in or out of `finally` block
    if (b) goto label;
           ^
---
*/

// Goto into finally block (forwards)
int w(bool b)
{
    if (b) goto label;
    try
    {
    }
    finally
    {
    label: {}
    }
    return 1;
}

// // Goto into finally block (backwards)
int x(bool b)
{
    try
    {
    }
    finally
    {
    label: {}
    }
    if (b) goto label;
    return 1;
}

// Goto out of finally block (forwards)
int y(bool b)
{
    try
    {
    }
    finally
    {
    if (b) goto label;
    }
    label: {}
    return 1;
}

// // Goto out of finally block (backwards)
int z(bool b)
{
    label: {}
    try
    {
    }
    finally
    {
    if (b) goto label;
    }
    return 1;
}
