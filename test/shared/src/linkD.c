#include <stdlib.h>
#include <assert.h>

extern int runTests(void);

int main(int argc, char* argv[])
{
    return runTests() ? EXIT_SUCCESS : EXIT_FAILURE;
}
