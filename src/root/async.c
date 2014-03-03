
/* Copyright (c) 2009-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/async.c
 */

#define _MT 1

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#if _WIN32

#include <windows.h>
#include <errno.h>
#include <process.h>

#include "root.h"

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
    AsyncRead *aw = (AsyncRead *)calloc(1, sizeof(AsyncRead) +
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
    //printf("aw->filesdim = %p %d\n", this, filesdim);
    if (filesdim)
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
}

int AsyncRead::read(size_t i)
{
    FileData *f = &files[i];
    WaitForSingleObject(f->event, INFINITE);
    Sleep(0);                   // give up time slice
    return f->result;
}

void AsyncRead::dispose(AsyncRead *aw)
{
    free(aw);
}



unsigned __stdcall startthread(void *p)
{
    AsyncRead *aw = (AsyncRead *)p;

    //printf("aw->filesdim = %p %d\n", aw, aw->filesdim);
    for (size_t i = 0; i < aw->filesdim; i++)
    {   FileData *f = &aw->files[i];

        f->result = f->file->read();
        SetEvent(f->event);
    }
    _endthreadex(EXIT_SUCCESS);
    return EXIT_SUCCESS;                // if skidding
}

#elif __linux__  // Posix

#include <errno.h>
#include <pthread.h>
#include <time.h>

#include "root.h"

void *startthread(void *arg);

void err_abort(int status, const char *msg)
{
    fprintf(stderr, "fatal error = %d, %s\n", status, msg);
    exit(EXIT_FAILURE);
}

struct FileData
{
    File *file;
    int result;

    pthread_mutex_t mutex;
    pthread_cond_t cond;
    int value;
};

struct AsyncRead
{
    static AsyncRead *create(size_t nfiles);
    void addFile(File *file);
    void start();
    int read(size_t i);
    static void dispose(AsyncRead *);

    size_t filesdim;
    size_t filesmax;
    FileData files[1];
};


AsyncRead *AsyncRead::create(size_t nfiles)
{
    AsyncRead *aw = (AsyncRead *)calloc(1, sizeof(AsyncRead) +
                                (nfiles - 1) * sizeof(FileData));
    aw->filesmax = nfiles;
    return aw;
}

void AsyncRead::addFile(File *file)
{
    //printf("addFile(file = %p)\n", file);
    //printf("filesdim = %d, filesmax = %d\n", filesdim, filesmax);
    assert(filesdim < filesmax);
    FileData *f = &files[filesdim];
    f->file = file;

    int status = pthread_mutex_init(&f->mutex, NULL);
    if (status != 0)
        err_abort(status, "init mutex");
    status = pthread_cond_init(&f->cond, NULL);
    if (status != 0)
        err_abort(status, "init cond");

    filesdim++;
}

void AsyncRead::start()
{
    //printf("aw->filesdim = %p %d\n", this, filesdim);
    if (filesdim)
    {
        pthread_t thread_id;
        int status = pthread_create(&thread_id,
            NULL,
            &startthread,
            this);
        if (status != 0)
            err_abort(status, "create thread");
    }
}

int AsyncRead::read(size_t i)
{
    FileData *f = &files[i];

    // Wait for the event
    int status = pthread_mutex_lock(&f->mutex);
    if (status != 0)
        err_abort(status, "lock mutex");
    while (f->value == 0)
    {
        status = pthread_cond_wait(&f->cond, &f->mutex);
        if (status != 0)
            err_abort(status, "wait on condition");
    }
    status = pthread_mutex_unlock(&f->mutex);
    if (status != 0)
        err_abort(status, "unlock mutex");

    return f->result;
}

void AsyncRead::dispose(AsyncRead *aw)
{
    //printf("AsyncRead::dispose()\n");
    for (int i = 0; i < aw->filesdim; i++)
    {
        FileData *f = &aw->files[i];
        int status = pthread_cond_destroy(&f->cond);
        if (status != 0)
            err_abort(status, "cond destroy");
        status = pthread_mutex_destroy(&f->mutex);
        if (status != 0)
            err_abort(status, "mutex destroy");
    }
    free(aw);
}


void *startthread(void *p)
{
    AsyncRead *aw = (AsyncRead *)p;

    //printf("startthread: aw->filesdim = %p %d\n", aw, aw->filesdim);
    size_t dim = aw->filesdim;
    for (size_t i = 0; i < dim; i++)
    {   FileData *f = &aw->files[i];

        f->result = f->file->read();

        // Set event
        int status = pthread_mutex_lock(&f->mutex);
        if (status != 0)
            err_abort(status, "lock mutex");
        f->value = 1;
        status = pthread_cond_signal(&f->cond);
        if (status != 0)
            err_abort(status, "signal condition");
        status = pthread_mutex_unlock(&f->mutex);
        if (status != 0)
            err_abort(status, "unlock mutex");
    }

    return NULL;                        // end thread
}

#else

#include <stdio.h>
#include <errno.h>

#include "root.h"

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
    AsyncRead *aw = (AsyncRead *)calloc(1, sizeof(AsyncRead) +
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
    free(aw);
}

#endif
