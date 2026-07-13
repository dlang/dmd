import gc19675;
import memory19675;

void main()
{
	auto p = new ManualGC;
	auto s = p.profileStats();
	auto s2 = GC.profileStats();
	assert(s.numCollections[0] == 0);
}
