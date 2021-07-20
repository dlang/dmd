RangeError now has bounds information

Errors resulting from bad indexing will now contain the length of
the array that was sliced, as well as the offending index for `arr[bad]`,
or, for bad slices, `arr[bad1 .. bad2]`.

`RangeError` now has two sub-classes: `ArrayIndexError` and `ArraySliceError`,
and the corresponding druntime hooks `onArrayIndexError` and `onArraySliceError` were added.

For example, currently the following file:

---
void main()
{
    int[] a = [1, 2, 3];
    int b = a[7];
}
---

would yield this error when compiled and run:

$(CONSOLE
> dmd -run main.d
core.exception.RangeError@onlineapp.d(4): Range violation
$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)
??:? _d_arrayboundsp [0xd1f573cd]
onlineapp.d:4 _Dmain [0xd1f57334]
)

It now yields:

$(CONSOLE
> dmd -run main.d
core.exception.ArrayIndexError@onlineapp.d(4): index [7] exceeds array length 3
$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)
??:? _d_arraybounds_indexp [0xd1f573cd]
onlineapp.d:4 _Dmain       [0xd1f57334]
)

There's also an informative message for out of bounds slice operations:
---
void main()
{
    int[] a = [1, 2, 3];
    int b = a[2 .. 4];
}
---

$(CONSOLE
> dmd -run main.d
core.exception.ArrayIndexError@onlineapp.d(4): slice [2 .. 4] extends past array of length 3
$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)$(NDASH)
??:? _d_arraybounds_slicep [0xd1f573cd]
onlineapp.d:4 _Dmain       [0xd1f57334]
)

Associative Arrays remain unchanged for now.
