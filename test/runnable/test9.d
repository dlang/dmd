public:

// VECTOR

alias float[1] vector1;
alias float[2] vector2;
alias float[3] vector3;
alias float[4] vector4;

// POINT

typedef vector1 point1;
typedef vector2 point2;
typedef vector3 point3;
typedef vector4 point4;

// MATRIX

alias vector1[1] matrix1x1;
alias vector2[2] matrix2x2;
alias vector3[2] matrix2x3;
alias vector2[3] matrix3x2;
alias vector3[3] matrix3x3;
alias vector4[3] matrix3x4;
alias vector3[4] matrix4x3;
alias vector4[4] matrix4x4;

// QUATERNION

typedef vector3 normal;
typedef vector4 quaternion;

// LINE / PLANE

alias vector2 plane1; // ax = b
alias vector3 plane2; // ax+by = c
alias plane2 line2;
alias vector4 plane3; // ax+by+cz = d
alias plane3 plane;

// SPHERE

struct sphere1
{
  vector1 center;
  float radius;
}
alias sphere1 centeredrange;

struct sphere2
{
  vector2 center;
  float radius;
}
alias sphere2 circle;

struct sphere3
{
  vector3 center;
  float radius;
}
alias sphere3 sphere;

struct sphere4
{
  vector4 center;
  float radius;
}

// RAY

struct ray1
{
  point1 from;
  vector1 to;
}

struct ray2
{
  point2 from;
  vector2 to;
}

struct ray3
{
  point3 from;
  vector3 to;
}

struct ray4
{
  point4 from;
  vector4 to;
}

// RECT/BOX

struct box1
{
  point1 p1,p2;
}
alias box1 range;

struct box2
{
  point2 p1,p2;
}
alias box2 rect;

struct box3
{
  point3 p1,p2;
}
alias box3 box;

struct box4
{
  point4 p1,p2;
}


alias float mvfloat;
typedef mvfloat scalar0;
struct multivector0
{
  union
  {
    scalar0 scalar;
    mvfloat r;
  }
}

typedef mvfloat scalar1;
typedef mvfloat pseudoscalar1;
struct multivector1
{
  union
  {
    struct
    {
      scalar1 scalar;
      union
      {
        pseudoscalar1 pseudoscalar;
        pseudoscalar1 bivector;
      }
    }
    struct
    {
      mvfloat r;
      mvfloat i;
    }
    mvfloat v[2];
  }
}

typedef mvfloat scalar2;
//typedef mvfloat[2] vector2;
typedef mvfloat pseudoscalar2;
alias pseudoscalar2 bivector2;
struct multivector2
{
  union
  {
    struct
    {
      scalar2 scalar;
      vector2 vector;
      union
      {
        pseudoscalar2 pseudoscalar;
        pseudoscalar2 bivector;
      }
    }
    struct
    {
      mvfloat r;
      mvfloat i,j;
      mvfloat e;
    }
    mvfloat v[4];
  }
}

multivector2 add(multivector2 a,multivector2 b) // a + b
{
  multivector2 c;
  c.r = a.r+b.r;
  c.i = a.i+b.i;
  c.j = a.j+b.j;
  c.e = a.e+b.e;
  return c;
}

multivector2 sub(multivector2 a,multivector2 b) // a - b
{
  multivector2 c;
  c.r = a.r-b.r;
  c.i = a.i-b.i;
  c.j = a.j-b.j;
  c.e = a.e-b.e;
  return c;
}

multivector2 dual(multivector2 a) // ~a = (a * 1e)
{
  multivector2 c;
  c.r = a.r; c.i = -a.i; c.j = a.j; c.e = -a.e;
  return c;
}

multivector2 inner(multivector2 a,multivector2 b) // a . b = 0.5(ab + ba) 
{
  multivector2 c;
  c.r = a.r*b.r + a.i*b.i + a.j*b.j - a.e*b.e;
//c.r = a.r*b.r + a.i*b.i + a.j*b.j + a.e*b.e;
  return c;
}

multivector2 meet(multivector2 a,multivector2 b) // a v b = ~a . b = meet(a,b)
{
  return inner(dual(a),b);
}


multivector2 outer(multivector2 a,multivector2 b) // a ^ b = 0.5(ab - ba) = join(a,b)
{
  multivector2 c;
//c.r = a.r*b.r + a.i*b.i + a.j*b.j - a.e*b.e;
  c.i = a.r*b.i + a.i*b.r - a.j*b.e + a.e*b.j;
  c.j = a.r*b.j + a.i*b.e + a.j*b.r - a.e*b.i;
  c.e = a.r*b.e + a.i*b.j - a.j*b.i + a.e*b.r;
  return c;
}

multivector2 product(multivector2 a,multivector2 b) // ab = a * b + a ^ b
{
  multivector2 c;
  c.r = a.r*b.r + a.i*b.i + a.j*b.j - a.e*b.e;
  c.i = a.r*b.i + a.i*b.r - a.j*b.e + a.e*b.j;
  c.j = a.r*b.j + a.i*b.e + a.j*b.r - a.e*b.i;
  c.e = a.r*b.e + a.i*b.j - a.j*b.i + a.e*b.r;
  return c;
}

typedef mvfloat scalar3;
//typedef mvfloat[3] vector3;
typedef mvfloat[3] bivector3;
typedef mvfloat pseudoscalar3;
alias pseudoscalar3 trivector3;
struct multivector3
{
  union
  {
    struct
    {
      scalar3 scalar;
      vector3 vector;
      bivector3 bivector;
      union
      {
        pseudoscalar3 pseudoscalar;
        pseudoscalar3 trivector;
      }
    }
    struct
    {
      mvfloat r;
      mvfloat i,j,k;
      mvfloat K,J,I;
      mvfloat e;
    }
    mvfloat v[8];
  }
}

multivector3 add(multivector3 a,multivector3 b) // a + b
{
  multivector3 c;
  c.r = a.r+b.r;
  c.i = a.i+b.i;
  c.j = a.j+b.j;
  c.k = a.k+b.k;
  c.K = a.K+b.K;
  c.J = a.J+b.J;
  c.I = a.I+b.I;
  c.e = a.e+b.e;
  return c;
}

multivector3 sub(multivector3 a,multivector3 b) // a - b
{
  multivector3 c;
  c.r = a.r-b.r;
  c.i = a.i-b.i;
  c.j = a.j-b.j;
  c.k = a.k-b.k;
  c.K = a.K-b.K;
  c.J = a.J-b.J;
  c.I = a.I-b.I;
  c.e = a.e-b.e;
  return c;
}

multivector3 dual(multivector3 a) // ~a = (a * 1e)
{
  multivector3 c;
  c.r = -a.r; c.i = -a.i; c.j = a.j; c.k = a.k; c.K = -a.K; c.J = -a.J; c.I = a.I; c.e = a.e;
  return c;
}

multivector3 inner(multivector3 a,multivector3 b) // a . b = 0.5(ab + ba)
{
  multivector3 c;
//c.r = a.r*b.r + a.i*b.i + a.j*b.j + a.k*b.k - a.K*b.K - a.J*b.J - a.I*b.I - a.e*b.e;
  c.r = a.r*b.r + a.i*b.i + a.j*b.j + a.k*b.k + a.K*b.K + a.J*b.J + a.I*b.I + a.e*b.e;
  return c;
}

multivector3 meet(multivector3 a,multivector3 b) // a v b = ~a . b = meet(a,b)
{
  return inner(dual(a),b);
}

multivector3 outer(multivector3 a,multivector3 b) // a ^ b = 0.5(ab - ba)
{
  multivector3 c;
//c.r = a.r*b.r + a.i*b.i + a.j*b.j - a.k*b.k + a.K*b.K - a.J*b.J - a.I*b.I - a.e*b.e;
  c.i = a.r*b.i + a.i*b.r - a.j*b.K + a.K*b.j - a.k*b.J + a.J*b.k - a.I*b.e - a.e*b.I;
  c.j = a.r*b.j + a.i*b.K + a.j*b.r - a.K*b.i - a.k*b.I + a.J*b.e + a.I*b.k + a.e*b.J;
  c.K = a.r*b.K + a.i*b.j - a.j*b.i + a.K*b.r + a.k*b.e - a.J*b.I + a.I*b.J + a.e*b.k;
  c.k = a.r*b.k + a.i*b.J + a.j*b.I - a.K*b.e + a.k*b.r - a.J*b.i - a.I*b.j - a.e*b.K;
  c.J = a.r*b.J + a.i*b.k - a.j*b.e + a.K*b.I - a.k*b.i + a.J*b.r - a.I*b.K - a.e*b.j;
  c.I = a.r*b.I + a.i*b.e + a.j*b.k - a.K*b.J - a.k*b.j + a.J*b.K + a.I*b.r + a.e*b.i;
  c.e = a.r*b.e + a.i*b.I - a.j*b.J + a.K*b.k + a.k*b.K - a.J*b.j + a.I*b.i + a.e*b.r;
  return c;
}

multivector3 product(multivector3 a,multivector3 b) // ab = a * b + a ^ b
{
  multivector3 c;
  c.r = a.r*b.r + a.i*b.i + a.j*b.j - a.k*b.k + a.K*b.K - a.J*b.J - a.I*b.I - a.e*b.e;
  c.i = a.r*b.i + a.i*b.r - a.j*b.K + a.K*b.j - a.k*b.J + a.J*b.k - a.I*b.e - a.e*b.I;
  c.j = a.r*b.j + a.i*b.K + a.j*b.r - a.K*b.i - a.k*b.I + a.J*b.e + a.I*b.k + a.e*b.J;
  c.K = a.r*b.K + a.i*b.j - a.j*b.i + a.K*b.r + a.k*b.e - a.J*b.I + a.I*b.J + a.e*b.k;
  c.k = a.r*b.k + a.i*b.J + a.j*b.I - a.K*b.e + a.k*b.r - a.J*b.i - a.I*b.j - a.e*b.K;
  c.J = a.r*b.J + a.i*b.k - a.j*b.e + a.K*b.I - a.k*b.i + a.J*b.r - a.I*b.K - a.e*b.j;
  c.I = a.r*b.I + a.i*b.e + a.j*b.k - a.K*b.J - a.k*b.j + a.J*b.K + a.I*b.r + a.e*b.i;
  c.e = a.r*b.e + a.i*b.I - a.j*b.J + a.K*b.k + a.k*b.K - a.J*b.j + a.I*b.i + a.e*b.r;
  return c;
}

int main()
{
    return 0;
}
