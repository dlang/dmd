// https://github.com/dlang/dmd/issues/23745
// Nested functions whose inline verdicts depend on the order they are
// scanned in: groups of near-threshold visitors calling shared helpers.
// The varied identifier lengths give each symbol table its own layout.
module test23745;
struct Node { int val; int extra; Node* next; }

int processA(Node* root)
{
    int count;
    Node*[8] stack;
    int sp;

    void pushA(Node* n) { if (sp < 8) { stack[sp] = n; ++sp; ++count; } }
    Node* popA() { if (sp) { --sp; return stack[sp]; } return null; }
    void goNextA(Node* n) { if (n && n.next) { pushA(n.next); n.extra += count; } }
    void markA(Node* n) { n.extra = count + sp; ++count; }

    void visitA(Node* n)
    {
        void vaA(Node* x) { pushA(x); goNextA(x); markA(x); if (x.val > 1) visitA(x.next); }
        void vbAxxx(Node* x) { goNextA(x); markA(x); pushA(x); if (x.val > 2) visitA(x.next); }
        void vcAxxxxxx(Node* x) { markA(x); goNextA(x); if (x.val > 3) { pushA(x); visitA(x.next); } }
        void vdAxxxxxxxxx(Node* x) { pushA(x); markA(x); if (x.val > 4) visitA(x.next); goNextA(x); }
        void veAx(Node* x) { pushA(x); goNextA(x); markA(x); if (x.val > 5) visitA(x.next); }
        void vfAxxxx(Node* x) { goNextA(x); markA(x); pushA(x); if (x.val > 6) visitA(x.next); }
        switch (n.val % 6)
        {
            case 0: vaA(n); break;
            case 1: vbAxxx(n); break;
            case 2: vcAxxxxxx(n); break;
            case 3: vdAxxxxxxxxx(n); break;
            case 4: veAx(n); break;
            case 5: vfAxxxx(n); break;
            default: vaA(n); vfAxxxx(n); break;
        }
    }
    for (Node* n = root; n; n = n.next)
        visitA(n);
    while (auto n = popA())
        count += n.extra;
    return count;
}

int processB(Node* root)
{
    int count;
    Node*[8] stack;
    int sp;

    void pushBxxx(Node* n) { if (sp < 8) { stack[sp] = n; ++sp; ++count; } }
    Node* popBxxx() { if (sp) { --sp; return stack[sp]; } return null; }
    void goNextBxxx(Node* n) { if (n && n.next) { pushBxxx(n.next); n.extra += count; } }
    void markBxxx(Node* n) { n.extra = count + sp; ++count; }

    void visitBxxx(Node* n)
    {
        void dummy0B(Node* x) { x.extra += 0; }
        void dummy1Bx(Node* x) { x.extra += 1; }
        void dummy2Bxx(Node* x) { x.extra += 2; }
        void vaBxxx(Node* x) { pushBxxx(x); goNextBxxx(x); markBxxx(x); if (x.val > 1) visitBxxx(x.next); }
        void vbBxxxxxx(Node* x) { goNextBxxx(x); markBxxx(x); pushBxxx(x); if (x.val > 2) visitBxxx(x.next); }
        void vcBxxxxxxxxx(Node* x) { markBxxx(x); goNextBxxx(x); if (x.val > 3) { pushBxxx(x); visitBxxx(x.next); } }
        void vdBx(Node* x) { pushBxxx(x); markBxxx(x); if (x.val > 4) visitBxxx(x.next); goNextBxxx(x); }
        void veBxxxx(Node* x) { pushBxxx(x); goNextBxxx(x); markBxxx(x); if (x.val > 5) visitBxxx(x.next); }
        void vfBxxxxxxx(Node* x) { goNextBxxx(x); markBxxx(x); pushBxxx(x); if (x.val > 6) visitBxxx(x.next); }
        void vgBxxxxxxxxxx(Node* x) { markBxxx(x); goNextBxxx(x); if (x.val > 7) { pushBxxx(x); visitBxxx(x.next); } }
        void vhBxx(Node* x) { pushBxxx(x); markBxxx(x); if (x.val > 8) visitBxxx(x.next); goNextBxxx(x); }
        switch (n.val % 8)
        {
            case 0: vaBxxx(n); break;
            case 1: vbBxxxxxx(n); break;
            case 2: vcBxxxxxxxxx(n); break;
            case 3: vdBx(n); break;
            case 4: veBxxxx(n); break;
            case 5: vfBxxxxxxx(n); break;
            case 6: vgBxxxxxxxxxx(n); break;
            case 7: vhBxx(n); break;
            default: vaBxxx(n); vhBxx(n); break;
        }
    }
    for (Node* n = root; n; n = n.next)
        visitBxxx(n);
    while (auto n = popBxxx())
        count += n.extra;
    return count;
}

int processC(Node* root)
{
    int count;
    Node*[8] stack;
    int sp;

    void pushCxxxxxxx(Node* n) { if (sp < 8) { stack[sp] = n; ++sp; ++count; } }
    Node* popCxxxxxxx() { if (sp) { --sp; return stack[sp]; } return null; }
    void goNextCxxxxxxx(Node* n) { if (n && n.next) { pushCxxxxxxx(n.next); n.extra += count; } }
    void markCxxxxxxx(Node* n) { n.extra = count + sp; ++count; }

    void visitCxxxxxxx(Node* n)
    {
        void dummy0C(Node* x) { x.extra += 0; }
        void dummy1Cx(Node* x) { x.extra += 1; }
        void dummy2Cxx(Node* x) { x.extra += 2; }
        void vaCxxxxxxx(Node* x) { pushCxxxxxxx(x); goNextCxxxxxxx(x); markCxxxxxxx(x); if (x.val > 1) visitCxxxxxxx(x.next); }
        void vbCxxxxxxxxxx(Node* x) { goNextCxxxxxxx(x); markCxxxxxxx(x); pushCxxxxxxx(x); if (x.val > 2) visitCxxxxxxx(x.next); }
        void vcCxx(Node* x) { markCxxxxxxx(x); goNextCxxxxxxx(x); if (x.val > 3) { pushCxxxxxxx(x); visitCxxxxxxx(x.next); } }
        void vdCxxxxx(Node* x) { pushCxxxxxxx(x); markCxxxxxxx(x); if (x.val > 4) visitCxxxxxxx(x.next); goNextCxxxxxxx(x); }
        void veCxxxxxxxx(Node* x) { pushCxxxxxxx(x); goNextCxxxxxxx(x); markCxxxxxxx(x); if (x.val > 5) visitCxxxxxxx(x.next); }
        switch (n.val % 5)
        {
            case 0: vaCxxxxxxx(n); break;
            case 1: vbCxxxxxxxxxx(n); break;
            case 2: vcCxx(n); break;
            case 3: vdCxxxxx(n); break;
            case 4: veCxxxxxxxx(n); break;
            default: vaCxxxxxxx(n); veCxxxxxxxx(n); break;
        }
    }
    for (Node* n = root; n; n = n.next)
        visitCxxxxxxx(n);
    while (auto n = popCxxxxxxx())
        count += n.extra;
    return count;
}

int processD(Node* root)
{
    int count;
    Node*[8] stack;
    int sp;

    void pushDx(Node* n) { if (sp < 8) { stack[sp] = n; ++sp; ++count; } }
    Node* popDx() { if (sp) { --sp; return stack[sp]; } return null; }
    void goNextDx(Node* n) { if (n && n.next) { pushDx(n.next); n.extra += count; } }
    void markDx(Node* n) { n.extra = count + sp; ++count; }

    void visitDx(Node* n)
    {
        void dummy0D(Node* x) { x.extra += 0; }
        void vaDx(Node* x) { pushDx(x); goNextDx(x); markDx(x); if (x.val > 1) visitDx(x.next); }
        void vbDxxxx(Node* x) { goNextDx(x); markDx(x); pushDx(x); if (x.val > 2) visitDx(x.next); }
        void vcDxxxxxxx(Node* x) { markDx(x); goNextDx(x); if (x.val > 3) { pushDx(x); visitDx(x.next); } }
        void vdDxxxxxxxxxx(Node* x) { pushDx(x); markDx(x); if (x.val > 4) visitDx(x.next); goNextDx(x); }
        void veDxx(Node* x) { pushDx(x); goNextDx(x); markDx(x); if (x.val > 5) visitDx(x.next); }
        void vfDxxxxx(Node* x) { goNextDx(x); markDx(x); pushDx(x); if (x.val > 6) visitDx(x.next); }
        void vgDxxxxxxxx(Node* x) { markDx(x); goNextDx(x); if (x.val > 7) { pushDx(x); visitDx(x.next); } }
        void vhD(Node* x) { pushDx(x); markDx(x); if (x.val > 8) visitDx(x.next); goNextDx(x); }
        void viDxxx(Node* x) { pushDx(x); goNextDx(x); markDx(x); if (x.val > 9) visitDx(x.next); }
        void vjDxxxxxx(Node* x) { goNextDx(x); markDx(x); pushDx(x); if (x.val > 10) visitDx(x.next); }
        switch (n.val % 10)
        {
            case 0: vaDx(n); break;
            case 1: vbDxxxx(n); break;
            case 2: vcDxxxxxxx(n); break;
            case 3: vdDxxxxxxxxxx(n); break;
            case 4: veDxx(n); break;
            case 5: vfDxxxxx(n); break;
            case 6: vgDxxxxxxxx(n); break;
            case 7: vhD(n); break;
            case 8: viDxxx(n); break;
            case 9: vjDxxxxxx(n); break;
            default: vaDx(n); vjDxxxxxx(n); break;
        }
    }
    for (Node* n = root; n; n = n.next)
        visitDx(n);
    while (auto n = popDx())
        count += n.extra;
    return count;
}

int processE(Node* root)
{
    int count;
    Node*[8] stack;
    int sp;

    void pushExxxxxxxxxxxx(Node* n) { if (sp < 8) { stack[sp] = n; ++sp; ++count; } }
    Node* popExxxxxxxxxxxx() { if (sp) { --sp; return stack[sp]; } return null; }
    void goNextExxxxxxxxxxxx(Node* n) { if (n && n.next) { pushExxxxxxxxxxxx(n.next); n.extra += count; } }
    void markExxxxxxxxxxxx(Node* n) { n.extra = count + sp; ++count; }

    void visitExxxxxxxxxxxx(Node* n)
    {
        void vaEx(Node* x) { pushExxxxxxxxxxxx(x); goNextExxxxxxxxxxxx(x); markExxxxxxxxxxxx(x); if (x.val > 1) visitExxxxxxxxxxxx(x.next); }
        void vbExxxx(Node* x) { goNextExxxxxxxxxxxx(x); markExxxxxxxxxxxx(x); pushExxxxxxxxxxxx(x); if (x.val > 2) visitExxxxxxxxxxxx(x.next); }
        void vcExxxxxxx(Node* x) { markExxxxxxxxxxxx(x); goNextExxxxxxxxxxxx(x); if (x.val > 3) { pushExxxxxxxxxxxx(x); visitExxxxxxxxxxxx(x.next); } }
        void vdExxxxxxxxxx(Node* x) { pushExxxxxxxxxxxx(x); markExxxxxxxxxxxx(x); if (x.val > 4) visitExxxxxxxxxxxx(x.next); goNextExxxxxxxxxxxx(x); }
        void veExx(Node* x) { pushExxxxxxxxxxxx(x); goNextExxxxxxxxxxxx(x); markExxxxxxxxxxxx(x); if (x.val > 5) visitExxxxxxxxxxxx(x.next); }
        void vfExxxxx(Node* x) { goNextExxxxxxxxxxxx(x); markExxxxxxxxxxxx(x); pushExxxxxxxxxxxx(x); if (x.val > 6) visitExxxxxxxxxxxx(x.next); }
        void vgExxxxxxxx(Node* x) { markExxxxxxxxxxxx(x); goNextExxxxxxxxxxxx(x); if (x.val > 7) { pushExxxxxxxxxxxx(x); visitExxxxxxxxxxxx(x.next); } }
        switch (n.val % 7)
        {
            case 0: vaEx(n); break;
            case 1: vbExxxx(n); break;
            case 2: vcExxxxxxx(n); break;
            case 3: vdExxxxxxxxxx(n); break;
            case 4: veExx(n); break;
            case 5: vfExxxxx(n); break;
            case 6: vgExxxxxxxx(n); break;
            default: vaEx(n); vgExxxxxxxx(n); break;
        }
    }
    for (Node* n = root; n; n = n.next)
        visitExxxxxxxxxxxx(n);
    while (auto n = popExxxxxxxxxxxx())
        count += n.extra;
    return count;
}

int processF(Node* root)
{
    int count;
    Node*[8] stack;
    int sp;

    void pushFxxxxx(Node* n) { if (sp < 8) { stack[sp] = n; ++sp; ++count; } }
    Node* popFxxxxx() { if (sp) { --sp; return stack[sp]; } return null; }
    void goNextFxxxxx(Node* n) { if (n && n.next) { pushFxxxxx(n.next); n.extra += count; } }
    void markFxxxxx(Node* n) { n.extra = count + sp; ++count; }

    void visitFxxxxx(Node* n)
    {
        void dummy0F(Node* x) { x.extra += 0; }
        void vaFxxxxx(Node* x) { pushFxxxxx(x); goNextFxxxxx(x); markFxxxxx(x); if (x.val > 1) visitFxxxxx(x.next); }
        void vbFxxxxxxxx(Node* x) { goNextFxxxxx(x); markFxxxxx(x); pushFxxxxx(x); if (x.val > 2) visitFxxxxx(x.next); }
        void vcF(Node* x) { markFxxxxx(x); goNextFxxxxx(x); if (x.val > 3) { pushFxxxxx(x); visitFxxxxx(x.next); } }
        void vdFxxx(Node* x) { pushFxxxxx(x); markFxxxxx(x); if (x.val > 4) visitFxxxxx(x.next); goNextFxxxxx(x); }
        void veFxxxxxx(Node* x) { pushFxxxxx(x); goNextFxxxxx(x); markFxxxxx(x); if (x.val > 5) visitFxxxxx(x.next); }
        void vfFxxxxxxxxx(Node* x) { goNextFxxxxx(x); markFxxxxx(x); pushFxxxxx(x); if (x.val > 6) visitFxxxxx(x.next); }
        void vgFx(Node* x) { markFxxxxx(x); goNextFxxxxx(x); if (x.val > 7) { pushFxxxxx(x); visitFxxxxx(x.next); } }
        void vhFxxxx(Node* x) { pushFxxxxx(x); markFxxxxx(x); if (x.val > 8) visitFxxxxx(x.next); goNextFxxxxx(x); }
        void viFxxxxxxx(Node* x) { pushFxxxxx(x); goNextFxxxxx(x); markFxxxxx(x); if (x.val > 9) visitFxxxxx(x.next); }
        switch (n.val % 9)
        {
            case 0: vaFxxxxx(n); break;
            case 1: vbFxxxxxxxx(n); break;
            case 2: vcF(n); break;
            case 3: vdFxxx(n); break;
            case 4: veFxxxxxx(n); break;
            case 5: vfFxxxxxxxxx(n); break;
            case 6: vgFx(n); break;
            case 7: vhFxxxx(n); break;
            case 8: viFxxxxxxx(n); break;
            default: vaFxxxxx(n); viFxxxxxxx(n); break;
        }
    }
    for (Node* n = root; n; n = n.next)
        visitFxxxxx(n);
    while (auto n = popFxxxxx())
        count += n.extra;
    return count;
}
