// 405

template square(typeof(x) x)
{
    const square = x * x;
}

const b = square!(1.2);
