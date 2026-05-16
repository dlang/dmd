
module memory19675;

struct GC
{
    struct ProfileStats
    {
        size_t[10] numCollections;
    }
	static ProfileStats profileStats()
    {
        return typeof(return).init;
    }

}

