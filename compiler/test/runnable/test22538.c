// https://issues.dlang.org/show_bug.cgi?id=22537

static int sun();

int sunlight() { return sun(); }

int sun() { return 0; }

// https://issues.dlang.org/show_bug.cgi?id=22538

static int moon();

int moonlight() { return moon(); }

static int moon() { return 0; }

/***********************************/

int main()
{
    return sunlight() + moonlight();
}
