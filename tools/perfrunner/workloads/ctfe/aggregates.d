// CTFE workload: struct values, operator overloads, class allocation and
// virtual calls.
struct Vec
{
    long x, y;

    Vec opBinary(string op : "+")(Vec o) const
    {
        return Vec(x + o.x, y + o.y);
    }

    long dot(Vec o) const
    {
        return x * o.x + y * o.y;
    }
}

class Node
{
    long value;
    Node next;

    this(long value, Node next)
    {
        this.value = value;
        this.next = next;
    }

    long sum()
    {
        return value + (next ? next.sum() : 0);
    }
}

class Base
{
    long apply(long a)
    {
        return a + 1;
    }
}

class Derived : Base
{
    override long apply(long a)
    {
        return a * 2 - 1;
    }
}

long run(int n)
{
    auto acc = Vec(0, 0);
    Base b = new Derived;
    long total;
    foreach (i; 0 .. n)
    {
        acc = acc + Vec(i, 1);
        total += acc.dot(Vec(1, 2)) + b.apply(i);
    }

    Node head;
    foreach (i; 0 .. 200)
        head = new Node(i, head);
    foreach (i; 0 .. n / 100)
        total += head.sum();
    return total;
}

// The baseline evaluates a trivial input, so that both compiles do the same
// semantic analysis and differ only in the interpreting.
version (Baseline)
    enum result = run(1);
else
    enum result = run(50_000);
