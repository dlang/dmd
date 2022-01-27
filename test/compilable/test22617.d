// https://issues.dlang.org/show_bug.cgi?id=22617

int countWins(const uint[2] arr)
{
	uint[2] copy = arr;
        copy[0] = 0;
	return 0;
}

enum force = countWins([4, 8]);
