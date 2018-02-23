/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/visitor/semantic.d, _semantic.d)
 * Documentation:  https://dlang.org/phobos/dmd_visitor.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/visitor/semantic.d
 */

module dmd.visitor.semantic;

import dmd.astcodegen;
import dmd.visitor.parse_time;

/**
 * Classic SemanticVisitor class which implements visit methods for all the AST
 * nodes present in the compiler. The visit methods for AST nodes
 * created at parse time are inherited while the visiting methods
 * for AST nodes created at semantic time are implemented.
 */
extern (C++) class SemanticVisitor : ParseTimeVisitor!ASTCodegen
{
    alias visit = ParseTimeVisitor!ASTCodegen.visit;
public:
    void visit(ASTCodegen.ErrorStatement s) { visit(cast(ASTCodegen.Statement)s); }
    void visit(ASTCodegen.PeelStatement s) { visit(cast(ASTCodegen.Statement)s); }
    void visit(ASTCodegen.UnrolledLoopStatement s) { visit(cast(ASTCodegen.Statement)s); }
    void visit(ASTCodegen.SwitchErrorStatement s) { visit(cast(ASTCodegen.Statement)s); }
    void visit(ASTCodegen.DebugStatement s) { visit(cast(ASTCodegen.Statement)s); }
    void visit(ASTCodegen.DtorExpStatement s) { visit(cast(ASTCodegen.ExpStatement)s); }
    void visit(ASTCodegen.ForwardingStatement s) { visit(cast(ASTCodegen.Statement)s); }
    void visit(ASTCodegen.OverloadSet s) { visit(cast(ASTCodegen.Dsymbol)s); }
    void visit(ASTCodegen.LabelDsymbol s) { visit(cast(ASTCodegen.Dsymbol)s); }
    void visit(ASTCodegen.WithScopeSymbol s) { visit(cast(ASTCodegen.ScopeDsymbol)s); }
    void visit(ASTCodegen.ArrayScopeSymbol s) { visit(cast(ASTCodegen.ScopeDsymbol)s); }
    void visit(ASTCodegen.OverDeclaration s) { visit(cast(ASTCodegen.Declaration)s); }
    void visit(ASTCodegen.SymbolDeclaration s) { visit(cast(ASTCodegen.Declaration)s); }
    void visit(ASTCodegen.ThisDeclaration s) { visit(cast(ASTCodegen.VarDeclaration)s); }
    void visit(ASTCodegen.TypeInfoDeclaration s) { visit(cast(ASTCodegen.VarDeclaration)s); }
    void visit(ASTCodegen.TypeInfoStructDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoClassDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoInterfaceDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoPointerDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoArrayDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoStaticArrayDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoAssociativeArrayDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoEnumDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoFunctionDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoDelegateDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoTupleDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoConstDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoInvariantDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoSharedDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoWildDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.TypeInfoVectorDeclaration s) { visit(cast(ASTCodegen.TypeInfoDeclaration)s); }
    void visit(ASTCodegen.FuncAliasDeclaration s) { visit(cast(ASTCodegen.FuncDeclaration)s); }
    void visit(ASTCodegen.ErrorInitializer i) { visit(cast(ASTCodegen.Initializer)i); }
    void visit(ASTCodegen.ErrorExp e) { visit(cast(ASTCodegen.Expression)e); }
    void visit(ASTCodegen.ComplexExp e) { visit(cast(ASTCodegen.Expression)e); }
    void visit(ASTCodegen.StructLiteralExp e) { visit(cast(ASTCodegen.Expression)e); }
    void visit(ASTCodegen.SymOffExp e) { visit(cast(ASTCodegen.SymbolExp)e); }
    void visit(ASTCodegen.OverExp e) { visit(cast(ASTCodegen.Expression)e); }
    void visit(ASTCodegen.HaltExp e) { visit(cast(ASTCodegen.Expression)e); }
    void visit(ASTCodegen.DotTemplateExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.DotVarExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.DelegateExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.DotTypeExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.VectorExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.SliceExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.ArrayLengthExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.DelegatePtrExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.DelegateFuncptrExp e) { visit(cast(ASTCodegen.UnaExp)e); }
    void visit(ASTCodegen.DotExp e) { visit(cast(ASTCodegen.BinExp)e); }
    void visit(ASTCodegen.IndexExp e) { visit(cast(ASTCodegen.BinExp)e); }
    void visit(ASTCodegen.ConstructExp e) { visit(cast(ASTCodegen.AssignExp)e); }
    void visit(ASTCodegen.BlitExp e) { visit(cast(ASTCodegen.AssignExp)e); }
    void visit(ASTCodegen.RemoveExp e) { visit(cast(ASTCodegen.BinExp)e); }
    void visit(ASTCodegen.ClassReferenceExp e) { visit(cast(ASTCodegen.Expression)e); }
    void visit(ASTCodegen.VoidInitExp e) { visit(cast(ASTCodegen.Expression)e); }
    void visit(ASTCodegen.ThrownExceptionExp e) { visit(cast(ASTCodegen.Expression)e); }
}
