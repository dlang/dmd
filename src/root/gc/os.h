// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


// OS specific routines

void *os_mem_map(unsigned nbytes);
int os_mem_commit(void *base, unsigned offset, unsigned nbytes);
int os_mem_decommit(void *base, unsigned offset, unsigned nbytes);
int os_mem_unmap(void *base, unsigned nbytes);


// Threading

#if defined linux
#include <pthread.h>
#else
typedef long pthread_t;
pthread_t pthread_self();
#endif
