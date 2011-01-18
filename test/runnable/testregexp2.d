// PERMUTE_ARGS:

import std.stdio;
import std.regexp;
import std.string;
import std.utf;

/***************************************************/

void test1()
{
  RegExp octDigit=new RegExp("[0-7]",null);
  string s="1234";
  string o;

  o=format("%d %s\n",octDigit.test(s[0..4]),s[0..4]);
  printf("%.*s", o.length, o.ptr);
  o=format("%d %s\n",octDigit.test(s[1..4]),s[1..4]);
  printf("%.*s", o.length, o.ptr);
  o=format("%d %s\n",octDigit.test(s[2..4]),s[2..4]);
  printf("%.*s", o.length, o.ptr);
}

/***************************************************/

void test2()
{
  RegExp octDigit=new RegExp("[0-7]",null);
  string s="1234";
  string o;
  int i;

  i=octDigit.test(s[0..4]);
  o=format("%d %s\n",i,s[0..4]);
  printf("%.*s", o.length, o.ptr);
  assert(i == 1);

  i=octDigit.test(s[1..4]);
  o=format("%d %s\n",i,s[1..4]);
  printf("%.*s", o.length, o.ptr);
  assert(i == 1);

  i=octDigit.test(s[2..4]);
  o=format("%d %s\n",i,s[2..4]);
  printf("%.*s", o.length, o.ptr);
  assert(i == 1);
}

/***************************************************/

void test3()
{
    RegExp re = new RegExp(r"<(\/)?([^<>]+)>", null);
    if (re.test("A<B>bold</B>and<CODE>coded</CODE>",0))
    {
	writefln("nsub = %d", re.re_nsub);

	for (int i = 0; i <= re.re_nsub; i++)
	{
	    writefln("%d %d", re.pmatch[i].rm_so, re.pmatch[i].rm_eo);
	}

	assert(re.re_nsub == 2);

	assert(re.pmatch[0].rm_so == 1);
	assert(re.pmatch[0].rm_eo == 4);

	assert(re.pmatch[1].rm_so == -1);
	assert(re.pmatch[1].rm_eo == -1);

	assert(re.pmatch[2].rm_so == 2);
	assert(re.pmatch[2].rm_eo == 3);
    }
    else
	assert(0);
}


/***************************************************/

void test4()
{
        new RegExp (r"[\w]", null);
}


/***************************************************/

void test5()
{
    int i;

    if (auto m = std.regexp.search("abcade", "c"))
    {	writefln("%s[%s]%s", m.pre, m.match(0), m.post);
	string s = std.string.format("%s[%s]%s", m.pre, m.match(0), m.post);
	assert(s == "ab[c]ade");
    }

    foreach(m; RegExp("ab").search("abcabcabab"))
    {
	writefln("%s[%s]%s", m.pre, m.match(0), m.post);

	string s = std.string.format("%s[%s]%s", m.pre, m.match(0), m.post);
	switch (i)
	{
	    case 0: assert(s == "[ab]cabcabab"); break;
	    case 1: assert(s == "abc[ab]cabab"); break;
	    case 2: assert(s == "abcabc[ab]ab"); break;
	    case 3: assert(s == "abcabcab[ab]"); break;
	}
	i++;
    }
}

/***************************************************/

size_t foo6(string sample, string pat)
{
    validate(sample);
    validate(pat);
    writefln("sample = %s", cast(ubyte[])sample);
    size_t pos = std.regexp.find(sample, pat);
    writefln("Where = %s %s", cast(ubyte[])pat, pos);
    return pos;
}

void test6()
{
    size_t i;

    i = foo6("\u3026a\u2021\u5004b\u4011", "a\u2021\u5004b");
    assert(i == 3);
    i = foo6("\u3026a\u2021\u5004b\u4011", "a..b");
    assert(i == 3);

    i = foo6("1a23b4", "a23b");
    assert(i == 1);
    i = foo6("1a23b4", "a..b");
    assert(i == 1);
}

/***************************************************/

void test7()
{
  auto str= "foo";
  auto regex_str= r"fo[o]x";

  auto regex= new RegExp(regex_str);
  writefln("'%s' matches '%s' ? ", str, regex_str, 
      cast(bool) regex.test(str)); 
  assert(!cast(bool) regex.test(str));

  writefln("\n");
  auto regex_i= new RegExp(regex_str, "i");
  writefln("'%s' matches case insensitive '%s' ? ", str, regex_str, 
      cast(bool) regex_i.test(str));
  assert(!cast(bool) regex_i.test(str));
}

/***************************************************/


int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();

    printf("Success\n");
    return 0;
}
