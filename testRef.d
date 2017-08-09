uint testRefCall(uint[] arr)
{
        uint sum;
        foreach(uint i;0 .. cast(uint)arr.length)
        {
                testRefCall_add(sum, arr[i]);
        }
        return sum;
}

void testRefCall_add(ref uint sum, uint element)
{
        sum = sum + element; // works now as well
        return ;
}

pragma(msg, [1,2].testRefCall);
//static assert([1,2,3,4,5].testRefCall == 15);

