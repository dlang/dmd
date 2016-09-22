module ddmd.callgraph;

import ddmd.expression;
import ddmd.statement;
import ddmd.declaration;
import ddmd.func;
import ddmd.visitor;
import ddmd.dsymbol;

struct CallGraphEntry
{
    CallExp call;
    FuncDeclaration caller;
}

CallGraphEntry[] collectCalls(FuncDeclaration fd, bool recursive = false)
{
    static extern (C++) class CallCollector : Visitor
    {
        alias visit = super.visit;
        this(bool recurse)
        {
            this.recurse = recurse;
        }

    public:
        CallGraphEntry[] result;
        FuncDeclaration caller;
        const bool recurse;

        override void visit(ErrorStatement s)
        {
        }

        override void visit(Dsymbol) {}

        override void visit(PeelStatement s)
        {
            if (s.s)
                s.s.accept(this);
        }
        
        override void visit(ExpStatement s)
        {
             if (s.exp)
            {
                s.exp.accept(this);
            }
        }

        override void visit(IntegerExp e)
        {
        }
        override void visit(StringExp e)
        {
        }
        override void visit(ComplexExp e)
        {
        }

        override void visit(SymbolExp se)
        {
            // we probaby don't have to do anything here
        }

        override void visit(DeclarationExp de)
        {
            // we probaby don't have to do anything here
        }

        override void visit(UnaExp ue)
        {
            ue.e1.accept(this);
        }

        override void visit(BinExp be)
        {
            be.e1.accept(this);
            be.e2.accept(this);
        }

        override void visit(CallExp ce)
        {
            import std.algorithm;
            bool seen = (result[].map!(r => r.caller).canFind!((a,b) => a == b.f)(ce));

            foreach(arg;*ce.arguments)
            {
                arg.accept(this);
            }
            result ~= CallGraphEntry(ce, caller);
            if(recurse && !seen && ce.f && ce.f.fbody)
            {
                scope oldCaller = caller;
                caller = ce.f;
                ce.f.fbody.accept(this);
                caller = oldCaller;
            }

        }

        override void visit(IdentifierExp)
        {
            // don't know about this one...
            // maybe we can get by skipping it ?
        }


        override void visit(CondExp ce)
        {
            ce.econd.accept(this);
            ce.e2.accept(this);
            ce.e1.accept(this);
        }


        override void visit(DtorExpStatement s)
        {
        }
        
        override void visit(CompileStatement s)
        {
        }
        
        override void visit(CompoundStatement s)
        {
            if (s.statements)
            {
                foreach(stmt;*s.statements)
                {
                    stmt.accept(this);
                }
            }
        }
        
        override void visit(CompoundDeclarationStatement s)
        {
            visit(cast(CompoundStatement)s);
        }
        
        override void visit(UnrolledLoopStatement s)
        {
            if (s.statements)
            {
                foreach(stmt;*s.statements)
                {
                    s.accept(this);
                }
            }
        }
        
        override void visit(ScopeStatement s)
        {
            if (s.statement)
                s.statement.accept(this);
        }
        
        override void visit(WhileStatement s)
        {
            s.condition.accept(this);
            if (s._body)
                s._body.accept(this);
        }
        
        override void visit(DoStatement s)
        {
            s.condition.accept(this);
            if (s._body)
                s._body.accept(this);
        }
        
        override void visit(ForStatement s)
        {
            if (s._init)
                s._init.accept(this);
            if (s.condition)
                s.condition.accept(this);
            if (s.increment)
                s.increment.accept(this);
            if (s._body)
                s._body.accept(this);
        }
        
        override void visit(ForeachStatement s)
        {
            if(s.aggr)
                s.aggr.accept(this);
            if (s._body)
                s._body.accept(this);
        }
        
        override void visit(ForeachRangeStatement s)
        {
            if (s._body)
                s._body.accept(this);
        }
        
        override void visit(IfStatement s)
        {
            s.condition.accept(this);

            if (s.ifbody)
                s.ifbody.accept(this);
            if (s.elsebody)
                s.elsebody.accept(this);
        }
        
        override void visit(ConditionalStatement s)
        {
            s.condition.accept(this);
            if (s.ifbody)
                s.ifbody.accept(this);
            if (s.elsebody)
                s.elsebody.accept(this);
        }
        
        override void visit(PragmaStatement s)
        {
        }
        
        override void visit(StaticAssertStatement s)
        {
            if (s.sa && s.sa.exp)
                s.sa.exp.accept(this);
        }
        
        override void visit(SwitchStatement s)
        {
            s.condition.accept(this);
            if (s._body)
                s._body.accept(this);

            foreach(_case;*s.cases)
                _case.accept(this);
        }
        
        override void visit(CaseStatement s)
        {
            if (s.statement)
                s.statement.accept(this);
        }
        
        override void visit(CaseRangeStatement s)
        {
            if (s.statement)
                s.statement.accept(this);
        }
        
        override void visit(DefaultStatement s)
        {
            if (s.statement)
                s.statement.accept(this);
        }
        
        override void visit(GotoDefaultStatement s)
        {
        }
        
        override void visit(GotoCaseStatement s)
        {
        }
        
        override void visit(SwitchErrorStatement s)
        {
        }
        
        override void visit(ReturnStatement s)
        {
            if (s.exp)
                s.exp.accept(this);
        }
        
        override void visit(BreakStatement s)
        {
        }
        
        override void visit(ContinueStatement s)
        {
        }
        
        override void visit(SynchronizedStatement s)
        {
            if (s._body)
                s._body.accept(this);
        }
        
        override void visit(WithStatement s)
        {
            if (s._body)
                s._body.accept(this);
        }
        
        override void visit(TryCatchStatement s)
        {
            if (s._body)
                s._body.accept(this);
            if (s.catches)
            {
                foreach (c;*s.catches)
                {
                    if (c && c.handler)
                        c.handler.accept(this);
                }
            }
        }
        
        override void visit(TryFinallyStatement s)
        {
            if (s._body)
                s._body.accept(this);
            if (s.finalbody)
                s.finalbody.accept(this);
        }
        
        override void visit(OnScopeStatement s)
        {
        }
        
        override void visit(ThrowStatement s)
        {
        }
        
        override void visit(DebugStatement s)
        {
            if (s.statement)
                s.statement.accept(this);
        }
        
        override void visit(GotoStatement s)
        {
        }
        
        override void visit(LabelStatement s)
        {
            if (s.statement)
                s.statement.accept(this);
        }
        
        override void visit(AsmStatement s)
        {
        }
        
        override void visit(ImportStatement s)
        {
        }
    }

    scope cc = new CallCollector(recursive);
    if (fd.fbody) fd.fbody.accept(cc);
    return cc.result; 
}
