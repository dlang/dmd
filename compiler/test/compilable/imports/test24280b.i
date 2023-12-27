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
