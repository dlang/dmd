#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "utils.h"

#ifdef _WIN32
#define PLUGIN_SO1 "plugin1.dll"
#elif __APPLE__
#define PLUGIN_SO1 "plugin1.dylib"
#else
#define PLUGIN_SO1 "plugin1.so"
#endif

int main(int argc, char* argv[])
{
#if defined(__FreeBSD__)
    // workaround for Bugzilla 14824
    void *druntime = loadLib(argv[1]); // load druntime
    assert(druntime);
#endif
#if defined(__DragonFly__)
    // workaround for Bugzilla 14824
    void *druntime = loadLib(argv[1]); // load druntime
    assert(druntime);
#endif

    const size_t pathlen = strrchr(argv[0], '/') - argv[0] + 1;
    const size_t fullpathsize = pathlen + sizeof(PLUGIN_SO1);
    char *name1 = malloc(fullpathsize);
    memcpy(name1, argv[0], pathlen);
    memcpy(name1+pathlen, PLUGIN_SO1, sizeof(PLUGIN_SO1));
    char *name2 = malloc(fullpathsize);
    memcpy(name2, name1, fullpathsize);
    name2[pathlen+6] = '2';

    void* plugin1 = loadLib(name1);
    void* plugin2 = loadLib(name2);

    int (*plugin1_init)() = loadSym(plugin1, "plugin_init");
    int (*plugin1_term)() = loadSym(plugin1, "plugin_term");
    int (*runTests1)() = loadSym(plugin1, "runTests");
    int (*plugin2_init)() = loadSym(plugin2, "plugin_init");
    int (*plugin2_term)() = loadSym(plugin2, "plugin_term");
    int (*runTests2)() = loadSym(plugin2, "runTests");
    assert(plugin1_init());
    assert(runTests1());
    assert(plugin2_init());
    assert(runTests2());

    assert(plugin1_term());
    assert(closeLib(plugin1));
    assert(runTests2());

    plugin1 = loadLib(name1);
    plugin1_init = loadSym(plugin1, "plugin_init");
    plugin1_term = loadSym(plugin1, "plugin_term");
    runTests1 = loadSym(plugin1, "runTests");
    assert(plugin1_init());
    assert(runTests1());
    assert(runTests2());

    assert(plugin2_term());
    assert(closeLib(plugin2));
    assert(runTests1());

    assert(plugin1_term());
    assert(closeLib(plugin1));

    free(name1);
    free(name2);

#if defined(__FreeBSD__)
    closeLib(druntime);
#endif
#if defined(__DragonFly__)
    closeLib(druntime);
#endif
    return EXIT_SUCCESS;
}
