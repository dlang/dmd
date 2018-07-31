// PERMUTE_ARGS:
// REQUIRED_ARGS:

// NOTE: the shootout is under a BSD license
// The Great Computer Language Shootout
// http://shootout.alioth.debian.org/
//
// contributed by Sebastien Loisel

import std.math, std.stdio, std.string, std.conv;

alias fl F;
struct fl
{
    double a;

    static fl opCall() { fl f; f.a = 0; return f; }
    static fl opCall(fl v) { fl f; f.a = v.a; return f; }
    void set(double x)
    {
        if(x==0) { a=0; return; }
        int k=cast(int)log(fabs(x));
        a=round(x*exp(-k+6.0))*exp(k-6.0);
    }
    static fl opCall(int x) { fl f; f.set(x); return f; }
    static fl opCall(double x) { fl f; f.set(x); return f; }
    fl opAdd(fl y) { return fl(a+y.a); }
    fl opAddAssign(fl y) { this=(this)+y; return this; }
    fl opSub(fl y) { return fl(a-y.a); }
    fl opSubAssign(fl y) { this=(this)-y; return this; }
    fl opMul(fl y) { return fl(a*y.a); }
    fl opDiv(fl y) { return fl(a/y.a); }

    fl opAdd(int y) { return fl(a+y); }
    fl opSub(int y) { return fl(a-y); }
    fl opMul(int y) { return fl(a*y); }
    fl opDiv(int y) { return fl(a/y); }

    fl opAdd(double y) { return fl(a+y); }
    fl opSub(double y) { return fl(a-y); }
    fl opMul(double y) { return fl(a*y); }
    fl opDiv(double y) { return fl(a/y); }
}

struct ad
{
    F x, dx;
    static ad opCall() { ad t; t.x = F(0); t.dx = F(0); return t; }
    static ad opCall(int y) { ad t; t.x = F(y); t.dx = F(0); return t; }
    static ad opCall(F y) { ad t; t.x = y; t.dx = F(0); return t; }
    static ad opCall(F X, F DX) { ad t; t.x = X; t.dx = DX; return t; }
    ad opAdd(ad y) { return ad(x+y.x,dx+y.dx); }
    ad opSub(ad y) { return ad(x-y.x,dx-y.dx); }
    ad opMul(ad y) { return ad(x*y.x,dx*y.x+x*y.dx); }
    ad opDiv(ad y) { return ad(x/y.x,(dx*y.x-x*y.dx)/(y.x*y.x)); }
    ad opMul(F v) { return ad(x*v,dx*v); }
    ad opAdd(F v) { return ad(x+v,dx); }
}

F sqr(F x) { return x * x; }
ad sqr(ad x) { return x * x; }

F pow(F x, int i)
{
    if(i < 1) return F(1);
    if(i & 1) if(i == 1) return x; else return x * pow(x,i-1);
    return sqr(pow(x,i/2));
}
ad pow(ad x, int i)
{
    if(i < 1) return ad(1);
    if(i & 1) if(i == 1) return x; else return x * pow(x,i-1);
    return sqr(pow(x,i/2));
}

F rat(F x)
{
    F t = (x * F(2) + pow(x,2) * F(3) + pow(x,6) * F(7) + pow(x,11) * F(5) + F(1))
        / (x * F(5) - pow(x,3) * F(6) - pow(x,7) * F(3) + F(2));
    return t;
}
ad rat(ad x)
{
    ad t = (x * ad(2) + pow(x,2) * ad(3) + pow(x,6) * ad(7) + pow(x,11) * ad(5) + ad(1))
        / (x * ad(5) - pow(x,3) * ad(6) - pow(x,7) * ad(3) + ad(2));
    return t;
}

F newton(F x0, int n, trapezoid_method_rooter g)
{

    for(int i=0 ; i<n; i++)
    {
        ad val = g( ad(x0,F(1)) );    // ad = trapezoid_method_rooter(ad);
//**
        x0 = x0 - val.x / val.dx;
/+
        F t0 = val.x;
        F t1 = val.dx;
        x0 = x0 - t0 / t1;
+/
    }

    return x0;
}

struct trapezoid_method_rooter
{
    sqrintegrand g;
    ad g0;
    F y0, t0, t1;
    trapezoid_method_rooter opCall(sqrintegrand G, F Y0, F T0, F T1)
    {
        g = G;
        y0 = Y0;
        t0 = T0;
        t1 = T1;
        g0 = G(T0,Y0);              // ad = sqr/ratintegrand(float,float);
        return this;
    }
    ad opCall(ad y1)
    {
        return (g(ad(t1),y1) + g0) * ((t1-t0)/F(2)) + y0 - y1;        // ad = sqr/ratintegrand(ad,ad);
    }
}

F trapezoid_method(F t0, F dt, F y0, sqrintegrand g, int numsteps)
{
  for(int i = 0; i < numsteps; i++)
  {
      trapezoid_method_rooter solver;
      y0 = newton(y0,10,solver(g,y0,t0,t0+dt));
      t0 = t0 + dt;
  }
  return y0;
}

struct sqrintegrand
{
      ad opCall(F t, F y) { return ad(sqr(y)); }
      ad opCall(ad t, ad y) { return sqr(y); }
}

struct ratintegrand
{
    ad opCall(F t, F y) { return ad(rat(y) - t); }
    ad opCall(ad t, ad y) { return rat(y) - t; }
}

void integrate_functions(F x0, int n)
{
    sqrintegrand   i1;
    writeln("i1 ",pr(trapezoid_method(F(1), F(1)/F(n), x0, i1 ,n)));
}

char[] pr(fl x) { char[] s = new char[100]; int len = sprintf(s.ptr,"%.2e",x.a); return s[0..len]; }

int main(string[] args)
{
  int N = args.length > 1 ? to!int(args[1]) : 50;

  integrate_functions(F(0.02),N);
  return 0;
}
