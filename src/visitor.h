
#ifndef DMD_VISITOR_H
#define DMD_VISITOR_H

#include <assert.h>

class Statement;
class ErrorStatement;
class PeelStatement;
class ExpStatement;
class DtorExpStatement;
class CompileStatement;
class CompoundStatement;
class CompoundDeclarationStatement;
class UnrolledLoopStatement;
class ScopeStatement;
class WhileStatement;
class DoStatement;
class ForStatement;
class ForeachStatement;
class ForeachRangeStatement;
class IfStatement;
class ConditionalStatement;
class PragmaStatement;
class StaticAssertStatement;
class SwitchStatement;
class CaseStatement;
class CaseRangeStatement;
class DefaultStatement;
class GotoDefaultStatement;
class GotoCaseStatement;
class SwitchErrorStatement;
class ReturnStatement;
class BreakStatement;
class ContinueStatement;
class SynchronizedStatement;
class WithStatement;
class TryCatchStatement;
class TryFinallyStatement;
class OnScopeStatement;
class ThrowStatement;
class DebugStatement;
class GotoStatement;
class LabelStatement;
class AsmStatement;
class ImportStatement;

class Visitor
{
public:
    virtual void visit(Statement *s) { assert(0); }
    virtual void visit(ErrorStatement *s) { visit((Statement *)s); }
    virtual void visit(PeelStatement *s) { visit((Statement *)s); }
    virtual void visit(ExpStatement *s) { visit((Statement *)s); }
    virtual void visit(DtorExpStatement *s) { visit((ExpStatement *)s); }
    virtual void visit(CompileStatement *s) { visit((Statement *)s); }
    virtual void visit(CompoundStatement *s) { visit((Statement *)s); }
    virtual void visit(CompoundDeclarationStatement *s) { visit((CompoundStatement *)s); }
    virtual void visit(UnrolledLoopStatement *s) { visit((Statement *)s); }
    virtual void visit(ScopeStatement *s) { visit((Statement *)s); }
    virtual void visit(WhileStatement *s) { visit((Statement *)s); }
    virtual void visit(DoStatement *s) { visit((Statement *)s); }
    virtual void visit(ForStatement *s) { visit((Statement *)s); }
    virtual void visit(ForeachStatement *s) { visit((Statement *)s); }
    virtual void visit(ForeachRangeStatement *s) { visit((Statement *)s); }
    virtual void visit(IfStatement *s) { visit((Statement *)s); }
    virtual void visit(ConditionalStatement *s) { visit((Statement *)s); }
    virtual void visit(PragmaStatement *s) { visit((Statement *)s); }
    virtual void visit(StaticAssertStatement *s) { visit((Statement *)s); }
    virtual void visit(SwitchStatement *s) { visit((Statement *)s); }
    virtual void visit(CaseStatement *s) { visit((Statement *)s); }
    virtual void visit(CaseRangeStatement *s) { visit((Statement *)s); }
    virtual void visit(DefaultStatement *s) { visit((Statement *)s); }
    virtual void visit(GotoDefaultStatement *s) { visit((Statement *)s); }
    virtual void visit(GotoCaseStatement *s) { visit((Statement *)s); }
    virtual void visit(SwitchErrorStatement *s) { visit((Statement *)s); }
    virtual void visit(ReturnStatement *s) { visit((Statement *)s); }
    virtual void visit(BreakStatement *s) { visit((Statement *)s); }
    virtual void visit(ContinueStatement *s) { visit((Statement *)s); }
    virtual void visit(SynchronizedStatement *s) { visit((Statement *)s); }
    virtual void visit(WithStatement *s) { visit((Statement *)s); }
    virtual void visit(TryCatchStatement *s) { visit((Statement *)s); }
    virtual void visit(TryFinallyStatement *s) { visit((Statement *)s); }
    virtual void visit(OnScopeStatement *s) { visit((Statement *)s); }
    virtual void visit(ThrowStatement *s) { visit((Statement *)s); }
    virtual void visit(DebugStatement *s) { visit((Statement *)s); }
    virtual void visit(GotoStatement *s) { visit((Statement *)s); }
    virtual void visit(LabelStatement *s) { visit((Statement *)s); }
    virtual void visit(AsmStatement *s) { visit((Statement *)s); }
    virtual void visit(ImportStatement *s) { visit((Statement *)s); }
};

#endif /* DMD_VISITOR_H */
