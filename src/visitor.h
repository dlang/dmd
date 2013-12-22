
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

class Type;
class TypeError;
class TypeNext;
class TypeBasic;
class TypeVector;
class TypeArray;
class TypeSArray;
class TypeDArray;
class TypeAArray;
class TypePointer;
class TypeReference;
class TypeFunction;
class TypeDelegate;
class TypeQualified;
class TypeIdentifier;
class TypeInstance;
class TypeTypeof;
class TypeReturn;
class TypeStruct;
class TypeEnum;
class TypeTypedef;
class TypeClass;
class TypeTuple;
class TypeSlice;
class TypeNull;

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

    virtual void visit(Type *t) { assert(0); }
    virtual void visit(TypeError *t) { visit((Type *)t); }
    virtual void visit(TypeNext *t) { visit((Type *)t); }
    virtual void visit(TypeBasic *t) { visit((Type *)t); }
    virtual void visit(TypeVector *t) { visit((Type *)t); }
    virtual void visit(TypeArray *t) { visit((TypeNext *)t); }
    virtual void visit(TypeSArray *t) { visit((TypeArray *)t); }
    virtual void visit(TypeDArray *t) { visit((TypeArray *)t); }
    virtual void visit(TypeAArray *t) { visit((TypeArray *)t); }
    virtual void visit(TypePointer *t) { visit((TypeNext *)t); }
    virtual void visit(TypeReference *t) { visit((TypeNext *)t); }
    virtual void visit(TypeFunction *t) { visit((TypeFunction *)t); }
    virtual void visit(TypeDelegate *t) { visit((TypeNext *)t); }
    virtual void visit(TypeQualified *t) { visit((Type *)t); }
    virtual void visit(TypeIdentifier *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeInstance *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeTypeof *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeReturn *t) { visit((TypeQualified *)t); }
    virtual void visit(TypeStruct *t) { visit((Type *)t); }
    virtual void visit(TypeEnum *t) { visit((Type *)t); }
    virtual void visit(TypeTypedef *t) { visit((Type *)t); }
    virtual void visit(TypeClass *t) { visit((Type *)t); }
    virtual void visit(TypeTuple *t) { visit((Type *)t); }
    virtual void visit(TypeSlice *t) { visit((TypeNext *)t); }
    virtual void visit(TypeNull *t) { visit((Type *)t); }
};

#endif /* DMD_VISITOR_H */
