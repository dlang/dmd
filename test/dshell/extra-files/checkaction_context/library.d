// Phobos reduction

RefCounted!() impl;

struct RefCounted()
{

	void* _store;

	~this()
	{
		assert(_store);
	}

}
