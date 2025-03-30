#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "utils.h"

int main(int argc, char* argv[])
{
    if (argc != 2)
        return EXIT_FAILURE;
    void *h = loadLib(argv[1]); // load druntime
    assert(h != NULL);

    int (*rt_init)(void) = loadSym(h, "rt_init");
    int (*rt_term)(void) = loadSym(h, "rt_term");
    void* (*rt_loadLibrary)(const char*) = loadSym(h, "rt_loadLibrary");
    int (*rt_unloadLibrary)(void*) = loadSym(h, "rt_unloadLibrary");

    int res = EXIT_FAILURE;
    if (!rt_init()) goto Lexit;

    const size_t pathlen = strrchr(argv[0], '/') - argv[0] + 1;
    char *name = malloc(pathlen + sizeof(LIB_SO));
    memcpy(name, argv[0], pathlen);
    memcpy(name+pathlen, LIB_SO, sizeof(LIB_SO));

    void *dlib = rt_loadLibrary(name);
    free(name);
    assert(dlib);

    int (*runTests)(void) = loadSym(dlib, "runTests");
    assert(runTests());
    assert(rt_unloadLibrary(dlib));

    if (rt_term()) res = EXIT_SUCCESS;

Lexit:
    assert(closeLib(h));
    return res;
}
