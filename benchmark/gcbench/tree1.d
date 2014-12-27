/**
 * Benchmark the GC on tree building.  Thanks to Bearophile.
 *
 * Copyright: Copyright David Simcha 2011 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   David Simcha
 */

/*          Copyright David Simcha 2011 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
import std.stdio, std.conv, std.exception;

class TreeNode {
    private TreeNode left, right;
    private int item;

    this(int item) {
        this.item = item;
    }

    this(TreeNode left, TreeNode right, int item){
        this.left = left;
        this.right = right;
        this.item = item;
    }

    private static TreeNode bottomUpTree(int item, int depth) {
        if (depth > 0) {
            return new TreeNode(bottomUpTree(2 * item - 1, depth - 1),
                                bottomUpTree(2 * item, depth - 1),
                                item);
        } else {
            return new TreeNode(item);
        }
    }

    private int itemCheck() {
        if (left is null)
            return item;
        else
            return item + left.itemCheck() - right.itemCheck();
    }
}


void main(string[] args) {

    int n = args.length > 1 ? to!int(args[1]) : 14;
    int minDepth = args.length > 2 ? to!int(args[2]) : 4;

    int maxDepth = (minDepth + 2 > n) ? minDepth + 2 : n;
    int stretchDepth = maxDepth + 1;

    int check = (TreeNode.bottomUpTree(0,stretchDepth)).itemCheck();

    TreeNode longLivedTree = TreeNode.bottomUpTree(0, maxDepth);

    for (int depth = minDepth; depth <= maxDepth; depth += 2) {
        int iterations = 1 << (maxDepth - depth + minDepth);
        check = 0;

        foreach (int i; 1 .. iterations+1) {
            check += (TreeNode.bottomUpTree(i, depth)).itemCheck();
            check += (TreeNode.bottomUpTree(-i, depth)).itemCheck();
        }
    }
}
