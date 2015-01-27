
version(D_Version2)
{
	const string d2_shared = " __gshared ";
}
else
{
	const string d2_shared = "";
}

version(dynload)
{
	extern(Windows) void* LoadLibraryA(in char* dll);
	extern(Windows) void* GetProcAddress(void* lib, in char* name);

	alias void fnDllPrint();
	alias int fnGetglob();
	alias char* fnAlloc(int sz);
	alias void fnFree(char* p, int sz);

	mixin(d2_shared ~ "fnDllPrint* pDllPrint;");
	mixin(d2_shared ~ "fnGetglob* pGetglob;");
	mixin(d2_shared ~ "fnAlloc* pAlloc;");
	mixin(d2_shared ~ "fnFree* pFree;");
	mixin(d2_shared ~ "int* pGlobvar;");

	int loadLib()
	{
	   void* lib = LoadLibraryA("mydll2.dll".ptr);
	   assert(lib);
	   pDllPrint = cast(fnDllPrint*) GetProcAddress(lib, "D6mydll28dllprintFZv".ptr);
  	   pFree = cast(fnFree*) GetProcAddress(lib, "D6mydll24freeFPaiZv".ptr);
	   pAlloc = cast(fnAlloc*) GetProcAddress(lib, "D6mydll25allocFiZPa".ptr);
	   pGetglob = cast(fnGetglob*) GetProcAddress(lib, "D6mydll27getglobFZi".ptr);
	   pGlobvar = cast(int*) GetProcAddress(lib, "D6mydll27globvari".ptr);

	   assert(pDllPrint && pFree && pAlloc && pGetglob && pGlobvar);
	   return 0;
	}

	void dllprint()
	{
		(*pDllPrint)();
	}

	int getglob()
	{
		return (*pGetglob)();
	}

	char* alloc(int sz)
	{
		return (*pAlloc)(sz);
	}
	void free(char* p, int sz)
	{
		(*pFree)(p, sz);
	}
	@property int globvar()
	{
		return *pGlobvar;
	}
}
else
{
	import mydll2;
}

mixin(d2_shared ~ "Object syncobj;");

void runtest()
{
	// wait until lib loaded
	synchronized(syncobj) getglob();

	int g = globvar;

	char*[] mem;
	for(int i = 0; i < 10000; i++)
	{
		mem ~= alloc(16);
	}
	for(int i = 0; i < 10000; i++)
	{
		free(mem[i], 16);
	}
	
	dllprint();
}

version(D_Version2)
{
	import core.thread;

	class TestThread : Thread
	{
		this()
		{
			super(&runtest);
		}
	}
}
else
{
	import std.thread;

	class TestThread : Thread
	{
		int run()
		{
			runtest();
			return 0;
		}
		void join()
		{
			wait();
		}
	}

}

void test_threaded()
{
	syncobj = new Object;
	TestThread[] th;
	
	for(int i = 0; i < 10; i++)
		th ~= new TestThread();
	
	// don't run threads before lib loaded
	synchronized(syncobj) 
	{
		for(int i = 0; i < 5; i++)
			th[i].start();
	
		// create some threads before loading the lib, other later
		version(dynload) loadLib();
	}

	for(int i = 5; i < 10; i++)
		th[i].start();
	
	for(int i = 0; i < 10; i++)
		th[i].join();
}

int main()
{
   test_threaded();
   return 0;
}

