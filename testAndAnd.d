
bool aa(bool b1, bool b2)
{
  if (b1 && b2)
  {
    return 1;
  }
  else
  {
    return 0;
  }
}

static assert(aa(1, 1));
static assert(!aa(1, 0));
static assert(!aa(0, 1));
static assert(!aa(0, 0));

bool aaa(bool b1, bool b2, bool b3)
{
  if ((b1 && b2) && b3)
  {
    return 1;
  }
  else
  {
    return 0;
  }
}

static assert(aaa(1, 1, 1));
static assert(!aaa(1, 0, 1));
int[2] aaa2(bool b1, bool b2, bool b3, bool b4)
{
  int x = 0;
  if (b1 && ++x && b2 && x++ && b3 && (b4 || x++))
  {
    return [x, 1];
  }
  else
  {
    return [x, 0];
  }
}

static assert(aaa2(0, 0, 0, 0) == [0, 0]);
static assert(aaa2(0, 1, 0, 0) == [0, 0]);
static assert(aaa2(0, 0, 1, 0) == [0, 0]);
static assert(aaa2(0, 0, 0, 1) == [0, 0]);
static assert(aaa2(1, 0, 0, 1) == [1, 0]);
static assert(aaa2(1, 1, 0, 1) == [2, 0]);
static assert(aaa2(1, 0, 1, 0) == [1, 0]);
static assert(aaa2(1, 1, 1, 0) == [3, 1]);
static assert(aaa2(1, 1, 1, 1) == [2, 1]);


int[2] ooo2(bool b1, bool b2, bool b3, bool b4)
{
  int x1 = 0;
  int x2 = 0;
  int x3 = 0;
  if (b1 || x1++ || b2 || x2++ || b3 || (++x3 && b4))
  {
    return [x1 + x2 + x3, 1];
  }
  else
  {
    return [x1 + x2 + x3, 0];
  }
}

static assert(ooo2(1, 0, 1, 0) == [0, 1]);
static assert(ooo2(0, 1, 1, 0) == [1, 1]);
static assert(ooo2(0, 0, 0, 0) == [3, 0]);
static assert(ooo2(0, 0, 1, 0) == [2, 1]);
pragma(msg, ooo2(0, 0, 1, 0));
static assert(ooo2(0, 0, 0, 1) == [3, 1]); // oh god ...

