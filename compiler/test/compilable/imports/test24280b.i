struct S;

struct timespec
{
    int s;
};

typedef struct timespec Clock;

Clock now()
{
    Clock result;
    return result;
}

struct S
{
    Clock clock;
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

struct T { };
