/*
        Portions of this file are:
        Copyright Prototronics, 1987
        Totem Lake P.O. 8117
        Kirkland, Washington 98034
        (206) 820-1972
        Licensed to Digital Mars.

        June 11, 1987 from Ray Gardner's
        Denver, Colorado) public domain version

        Use qsort2.d instead of this file if a redistributable version of
        _adSort() is required.
*/

module rt.qsort;

/*
**    Sorts an array starting at base, of length nbr_elements, each
**    element of size width_bytes, ordered via compare_function; which
**    is called as  (*comp_fp)(ptr_to_element1, ptr_to_element2)
**    and returns < 0 if element1 < element2, 0 if element1 = element2,
**    > 0 if element1 > element2.  Most of the refinements are due to
**    R. Sedgewick.  See "Implementing Quicksort Programs", Comm. ACM,
**    Oct. 1978, and Corrigendum, Comm. ACM, June 1979.
*/

//debug=qsort;          // uncomment to turn on debugging printf's


struct Array
{
    size_t length;
    void*  ptr;
}


private const int _maxspan = 7; // subarrays of _maxspan or fewer elements
                                // will be sorted by a simple insertion sort

/* Adjust _maxspan according to relative cost of a swap and a compare.  Reduce
_maxspan (not less than 1) if a swap is very expensive such as when you have
an array of large structures to be sorted, rather than an array of pointers to
structures.  The default value is optimized for a high cost for compares. */


extern (C) void[] _adSort(Array a, TypeInfo ti)
{
  byte*[40] stack;              // stack
  byte* i, j;            // scan and limit pointers
  auto width = ti.tsize();

  auto base = cast(byte *)a.ptr;
  auto thresh = _maxspan * width;        // size of _maxspan elements in bytes
  auto sp = stack.ptr;                   // stack pointer
  auto limit = base + a.length * width;  // pointer past end of array
  while (1)                              // repeat until done then return
  {
    while (limit - base > thresh)        // if more than _maxspan elements
    {
      //swap middle, base
      ti.swap((cast(uint)(limit - base) >> 1) -
           (((cast(uint)(limit - base) >> 1)) % width) + base, base);

      i = base + width;                 // i scans from left to right
      j = limit - width;                // j scans from right to left

      if (ti.compare(i, j) > 0)         // Sedgewick's
        ti.swap(i, j);                  //    three-element sort
      if (ti.compare(base, j) > 0)      // sets things up
        ti.swap(base, j);               // so that
      if (ti.compare(i, base) > 0)      // *i <= *base <= *j
        ti.swap(i, base);               // *base is the pivot element

      while (1)
      {
        do                              // move i right until *i >= pivot
          i += width;
        while (ti.compare(i, base) < 0);
        do                              // move j left until *j <= pivot
          j -= width;
        while (ti.compare(j, base) > 0);
        if (i > j)                      // break loop if pointers crossed
          break;
        ti.swap(i, j);                  // else swap elements, keep scanning
      }
      ti.swap(base, j);                 // move pivot into correct place
      if (j - base > limit - i)         // if left subarray is larger...
      {
        sp[0] = base;                   // stack left subarray base
        sp[1] = j;                      //    and limit
        base = i;                       // sort the right subarray
      }
      else                              // else right subarray is larger
      {
        sp[0] = i;                      // stack right subarray base
        sp[1] = limit;                  //    and limit
        limit = j;                      // sort the left subarray
      }
      sp += 2;                          // increment stack pointer
      assert(sp < cast(byte**)stack + stack.length);
    }

    // Insertion sort on remaining subarray
    i = base + width;
    while (i < limit)
    {
      j = i;
      while (j > base && ti.compare(j - width, j) > 0)
      {
        ti.swap(j - width, j);
        j -= width;
      }
      i += width;
    }

    if (sp > stack.ptr)                 // if any entries on stack...
    {
      sp -= 2;                          // pop the base and limit
      base = sp[0];
      limit = sp[1];
    }
    else                                // else stack empty, all done
      return *cast(void[]*)(&a);
  }
  assert(0);
}


unittest
{
    debug(qsort) printf("array.sort.unittest()\n");

    int a[] = new int[10];

    a[0] = 23;
    a[1] = 1;
    a[2] = 64;
    a[3] = 5;
    a[4] = 6;
    a[5] = 5;
    a[6] = 17;
    a[7] = 3;
    a[8] = 0;
    a[9] = -1;

    a.sort;

    for (int i = 0; i < a.length - 1; i++)
    {
        //printf("i = %d", i);
        //printf(" %d %d\n", a[i], a[i + 1]);
        assert(a[i] <= a[i + 1]);
    }
}
