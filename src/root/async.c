
#define _MT 1

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#if _WIN32

#include <windows.h>
#include <stdio.h>
#include <errno.h>
#include <process.h>

#include "root.h"
#include "rmem.h"

static unsigned __stdcall startthread(void *p);

struct FileData
{
    File *file;
    int result;
    HANDLE event;
};

struct AsyncRead
{
    static AsyncRead *create(size_t nfiles);
    void addFile(File *file);
    void start();
    int read(size_t i);
    static void dispose(AsyncRead *);

    HANDLE hThread;

    size_t filesdim;
    size_t filesmax;
    FileData files[1];
};


AsyncRead *AsyncRead::create(size_t nfiles)
{
    AsyncRead *aw = (AsyncRead *)mem.calloc(1, sizeof(AsyncRead) +
				(nfiles - 1) * sizeof(FileData));
    aw->filesmax = nfiles;
    return aw;
}

void AsyncRead::addFile(File *file)
{
    //printf("addFile(file = %p)\n", file);
    //printf("filesdim = %d, filesmax = %d\n", filesdim, filesmax);
    assert(filesdim < filesmax);
    files[filesdim].file = file;
    files[filesdim].event = CreateEvent(NULL, TRUE, FALSE, NULL);
    ResetEvent(files[filesdim].event);
    filesdim++;
}

void AsyncRead::start()
{
    unsigned threadaddr;
    hThread = (HANDLE) _beginthreadex(NULL,
	0,
	&startthread,
	this,
	0,
	(unsigned *)&threadaddr);

    if (hThread)
    {
	SetThreadPriority(hThread, THREAD_PRIORITY_HIGHEST);
    }
    else
    {
	assert(0);
    }
}

int AsyncRead::read(size_t i)
{
    FileData *f = &files[i];
    WaitForSingleObject(f->event, INFINITE);
    Sleep(0);			// give up time slice
    return f->result;
}

void AsyncRead::dispose(AsyncRead *aw)
{
    delete aw;
}



unsigned __stdcall startthread(void *p)
{
    AsyncRead *aw = (AsyncRead *)p;

    for (size_t i = 0; i < aw->filesdim; i++)
    {	FileData *f = &aw->files[i];

	f->result = f->file->read();
	SetEvent(f->event);
    }
    _endthreadex(EXIT_SUCCESS);
    return EXIT_SUCCESS;		// if skidding
}

#else

#include <stdio.h>
#include <errno.h>

#include "root.h"
#include "rmem.h"

struct FileData
{
    File *file;
    int result;
    //HANDLE event;
};

struct AsyncRead
{
    static AsyncRead *create(size_t nfiles);
    void addFile(File *file);
    void start();
    int read(size_t i);
    static void dispose(AsyncRead *);

    //HANDLE hThread;

    size_t filesdim;
    size_t filesmax;
    FileData files[1];
};


AsyncRead *AsyncRead::create(size_t nfiles)
{
    AsyncRead *aw = (AsyncRead *)mem.calloc(1, sizeof(AsyncRead) +
				(nfiles - 1) * sizeof(FileData));
    aw->filesmax = nfiles;
    return aw;
}

void AsyncRead::addFile(File *file)
{
    //printf("addFile(file = %p)\n", file);
    //printf("filesdim = %d, filesmax = %d\n", filesdim, filesmax);
    assert(filesdim < filesmax);
    files[filesdim].file = file;
    //files[filesdim].event = CreateEvent(NULL, TRUE, FALSE, NULL);
    //ResetEvent(files[filesdim].event);
    filesdim++;
}

void AsyncRead::start()
{
}

int AsyncRead::read(size_t i)
{
    FileData *f = &files[i];
    f->result = f->file->read();
    return f->result;
}

void AsyncRead::dispose(AsyncRead *aw)
{
    delete aw;
}

#endif
