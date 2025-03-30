module lib13666;

template drt_envvars()
{
    extern(C) __gshared bool enabled = false;
}

bool foo()
{
	return drt_envvars!().enabled;
}
