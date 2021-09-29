/// compute memory requirements of AA-literal
extern AALayout computeLayout(AssocArrayLiteralExp* aale);

/// Prepare the bucket array for emission
extern BucketUsageInfo MakeAALiteralInfo(AssocArrayLiteralExp* aale, AALayout aaLayout, AABucket* bucketMem);

struct AALayout
{
    const uint32_t init_size;
    const uint32_t keysz;
    const uint32_t valsz;
    const uint32_t valalign;
    const uint32_t valoff;
    const uint32_t padSize;
    const uint32_t entrySize;
};

struct AABucket
{
    uint64_t hash;
    uint32_t elementIndex;
};

struct BucketUsageInfo
{
    uint32_t used;
    uint32_t first_used;
    uint32_t last_used;
};

