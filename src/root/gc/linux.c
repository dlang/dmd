// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>


/*************************************
 * This is all necessary to get fd initialized at startup.
 */

#define FDMAP 0

#if FDMAP
#include <fcntl.h>

struct OS_INIT
{
    static int fd;

    OS_INIT();
};

OS_INIT os_init;

int OS_INIT::fd = 0;

OS_INIT::OS_INIT()
{
    fd = open("/dev/zero", O_RDONLY);
}
#endif

/***********************************
 * Map memory.
 */

void *os_mem_map(unsigned nbytes)
{   void *p;

    errno = 0;
#if FDMAP
    p = mmap(NULL, nbytes, PROT_READ | PROT_WRITE, MAP_PRIVATE, OS_INIT::fd, 0);
#else
    p = mmap(NULL, nbytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
#endif
    return (p == MAP_FAILED) ? NULL : p;
}

/***********************************
 * Commit memory.
 * Returns:
 *      0       success
 *      !=0     failure
 */

int os_mem_commit(void *base, unsigned offset, unsigned nbytes)
{
    return 0;
}


/***********************************
 * Decommit memory.
 * Returns:
 *      0       success
 *      !=0     failure
 */

int os_mem_decommit(void *base, unsigned offset, unsigned nbytes)
{
    return 0;
}

/***********************************
 * Unmap memory allocated with os_mem_map().
 * Returns:
 *      0       success
 *      !=0     failure
 */

int os_mem_unmap(void *base, unsigned nbytes)
{
    return munmap(base, nbytes);
}




