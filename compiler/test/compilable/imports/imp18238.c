__attribute__((packed)) struct A18238 // packed ignored
{
    long long x : 8;
};

struct __attribute__((packed)) B18238 // packed
{
    long long x : 8;
};

struct C18238
{
    __attribute__((packed))	      // packed
    long long x : 8;
};

struct D18238
{
    long long x : 8;
} __attribute__((packed));	      // packed

struct E18238
{
    __attribute__((aligned(1)))       // explicitly aligned
    long long x : 8;
} __attribute__((packed));

struct F18238
{
    __attribute__((aligned(2)))       // explicitly aligned
    long long x : 8;
} __attribute__((packed));

struct G18238
{
    __attribute__((aligned(4)))       // explicitly aligned
    long long x : 8;
} __attribute__((packed));

struct H18238
{
    __attribute__((aligned(8)))       // explicitly aligned
    long long x : 8;
} __attribute__((packed));

struct __attribute__((aligned(1))) I18238 // not packed
{
    long long x : 8;
};

struct J18238
{
    __attribute__((aligned(1)))       // not packed
    long long x : 8;
};

struct K18238
{
    long long x : 8;
} __attribute__((aligned(1)));       // not packed
