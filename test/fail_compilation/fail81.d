class Alocator(T)
{
}

class Module
{
	GObject createObject();
}

class Factory(T): Module
{
	GObject createObject();
}

//typedef Alocator!(Object) GObject;
alias Alocator!(Object) GObject;

void main()
{
	auto mod=new Factory!(Module);
}

