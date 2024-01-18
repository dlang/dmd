// EXTRA_SOURCES: imports/test24280b.i

struct timespec
{
    int s;
};

/* https://issues.dlang.org/show_bug.cgi?id=24303 */

typedef struct {} Slice;

struct Lang
{
    Slice *slices;
};

void langmap(struct Lang *self)
{
    Slice slice = *self->slices;
}

/* https://issues.dlang.org/show_bug.cgi?id=24306 */

struct T;
