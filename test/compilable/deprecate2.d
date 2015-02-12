// REQUIRED_ARGS: -d
// PERMUTE_ARGS: -dw

// Test cases using deprecated features

/**************************************************
   Segfault. From compile1.d
   http://www.digitalmars.com/d/archives/6376.html
**************************************************/

alias float[2] vector2;
alias vector2 point2;  // if I change this typedef to alias it works fine

float distance(point2 a, point2 b)
{
  point2 d;
  d[0] = b[0] - a[0]; // if I comment out this line it won't crash
  return 0.0f;
}

class A3836
{
    void fun() {}
}
class B3836 : A3836
{
    void fun() {}
}
