This directory will get copied to dlang.org and cleared when master gets
merged into stable prior to a new release.

How to add a new changelog entry to the pending changelog?
==========================================================

Create a new file in the `changelog` folder. It should end with `.dd` and look
similar to a git commit message. The first line represents the title of the change.
After an empty line follows the long description:

```
My fancy title of the new feature

A long description of the new feature in `std.range`.
It can be followed by an example:
-------
import std.range : padLeft, padRight;
import std.algorithm.comparison : equal;

assert([1, 2, 3, 4, 5].padLeft(0, 7).equal([0, 0, 1, 2, 3, 4, 5]));

assert("Hello World!".padRight('!', 15).equal("Hello World!!!!"));
-------
and links to the documentation, e.g. $(REF drop, std, range) or
$(REF_ALTTEXT a custom name for the function, drop, std, range).

Links to the spec can look like this $(LINK2 $(ROOT_DIR)spec/module.html, this)
and of course you can link to other $(LINK2 https://forum.dlang.org/, external resources).
```

The title can't contain links (it's already one).
For more infos, see the [Ddoc spec](https://dlang.org/spec/ddoc.html).

Preview changes
---------------

If you have cloned the [tools](https://github.com/dlang/tools) and [dlang.org](https://github.com/dlang/dlang.org) repo,
you can preview the changelog with:

```
make -C ../dlang.org -f posix.mak pending_changelog
```
