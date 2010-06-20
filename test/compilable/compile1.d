// PERMUTE_ARGS:

alias float[2] vector2;
typedef vector2 point2;  // if I change this typedef to alias it works fine

float distance(point2 a, point2 b)
{
  point2 d;
  d[0] = b[0] - a[0]; // if I comment out this line it won't crash
  return 0.0f;
}

