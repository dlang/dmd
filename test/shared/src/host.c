#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <assert.h>

int main(int argc, char* argv[])
{
    const size_t pathlen = strrchr(argv[0], '/') - argv[0] + 1;
    char *name = malloc(pathlen + sizeof("plugin1.so"));
    memcpy(name, argv[0], pathlen);
    memcpy(name+pathlen, "plugin1.so", sizeof("plugin1.so"));

    void* plugin1 = dlopen(name, RTLD_LAZY);
    name[pathlen + sizeof("plugin1.so") - 5] = '2';
    void* plugin2 = dlopen(name, RTLD_LAZY);

    int (*runTests1)() = dlsym(plugin1, "runTests");
    int (*runTests2)() = dlsym(plugin2, "runTests");
    assert(runTests1());
    assert(runTests2());

    assert(dlclose(plugin1) == 0);
    assert(runTests2());

    name[pathlen + sizeof("plugin1.so") - 5] = '1';
    plugin1 = dlopen(name, RTLD_LAZY);
    runTests1 = dlsym(plugin1, "runTests");
    assert(runTests1());
    assert(runTests2());

    assert(dlclose(plugin2) == 0);
    assert(runTests1());

    assert(dlclose(plugin1) == 0);

    free(name);
    return EXIT_SUCCESS;
}
