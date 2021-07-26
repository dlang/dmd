module dmd.property;

import dmd.expression;
import dmd.dscope;
import dmd.dsymbol;
import dmd.statement;
import dmd.expressionsem;
import dmd.tokens;
import dmd.mtype;
import dmd.identifier;
import dmd.globals;
import dmd.arraytypes;
import dmd.declaration;
import dmd.dtemplate;
import dmd.func;
import dmd.sideeffect;
import core.stdc.stdio;

/********************************************************************************
* Helper function to resolve `@property` functions in a `BinAssignExp`.
* It rewrites expressions of the form `e1.prop @= e2` to `e1.x(e1.x @ e2)`
* if 'e1` is a type, otherwise it rewrites to
* `((auto ref _e1) => _e1.prop(_e1.prop @ e2))(e1)`
* Params:
*      e = the binary assignment expression to rewrite
*      sc = the semantic scope
* Returns:
*      the rewritten expression if the procedure succeeds, an `ErrorExp` if the
*      and error is encountered, or `null` if `e.e1` is not a `@property` function.
*/
Expression SemanticProp(BinAssignExp e, Scope* sc)
{
    
    // This will convert id expressions to var expressions
    Expression e1x = e.e1.expressionSemantic(sc);
    Expression e2x = e.e2.expressionSemantic(sc);

    if (e1x.op == TOK.error)
        return e1x;
    if (e2x.op == TOK.error)
        return e2x;

    // This will convert a var expression to a call expression
    e1x = resolveProperties(sc, e1x);
    e2x = resolveProperties(sc, e2x);
    if (e1x.op == TOK.error)
        return e1x;
    if (e2x.op == TOK.error)
        return e2x;

    // Check for property assignment.
    // https://issues.dlang.org/show_bug.cgi?id=8006
    if (e1x.op == TOK.call)
    {
        // Only rewrite @property functions that are not lvalues
        auto e1_call = cast(CallExp)e1x;
        auto tf = (e1_call.e1.type.ty) == Tfunction ? cast(TypeFunction)e1_call.e1.type : null;
        if (tf && tf.isproperty && !e1_call.isLvalue)
        {
            // Need to rewrite e1.prop @= e2
            // if e1 is a type (e.g. static @property functions) then rewrite to
            //   e1.x(e1.x() @ e2)
            // otherwise rewrite to
            //   ((auto ref _e1) => _e1.prop(_e1.prop() @ e2))(e1)

            // We need to get e1.
            Expression e1 = e.e1.copy();

            bool noLambda = false;
            if (e1.op == TOK.dotIdentifier)
            {
                auto e1_dotId = cast(DotIdExp)e1;
                noLambda = e1_dotId.e1.op == TOK.type;
            }
            else if (e1.op == TOK.identifier || e1.op == TOK.call || e1.op == TOK.variable)
            {
                noLambda = true;
            }

            // create expression `_e1.prop() @ e2`
            Expression createOperation(Expression _e1PropCall)
            {
                Expression expOp = null;
                switch(e.op)
                {
                    case TOK.concatenateAssign:
                        expOp = new CatExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.addAssign:
                        expOp = new AddExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.minAssign:
                        expOp = new MinExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.mulAssign:
                        expOp = new MulExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.divAssign:
                        expOp = new DivExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.modAssign:
                        expOp = new ModExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.powAssign:
                        expOp = new PowExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.andAssign:
                        expOp = new AndExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.orAssign:
                        expOp = new OrExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.xorAssign:
                        expOp = new XorExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.leftShiftAssign:
                        expOp = new ShlExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.rightShiftAssign:
                        expOp = new ShrExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.unsignedRightShiftAssign:
                        expOp = new UshrExp(e.loc, _e1PropCall, e2x);
                        break;
                    case TOK.plusPlus:
                        expOp = new PostExp(TOK.plusPlus, e.loc, e2x);
                        break;
                    case TOK.minusMinus:
                        expOp = new PostExp(TOK.minusMinus, e.loc, e2x);
                        break;
                    case TOK.prePlusPlus:
                        expOp = new PostExp(TOK.prePlusPlus, e.loc, e2x);
                        break;
                    case TOK.preMinusMinus:
                        expOp = new PostExp(TOK.preMinusMinus, e.loc, e2x);
                        break;

                    default:
                        assert(false);  // operator was not handled
                }

                return expOp;
            }

            Expression result = null;

            // e.g. nested @property function, module-level function, or e1 is a type
            if (noLambda)
            {
                // Create expression `e1.prop()` or `prop()`
                auto getterCall = new CallExp(e.loc, e1);

                // Create expression `e1.prop() @ e2` or `prop() @ e2`
                auto e1DotProp_op_e2 = createOperation(getterCall);

                // create expression `e1.prop(e1.prop() @ e2)` or `prop(prop() @ e2)`
                auto setterCall = new CallExp(e.loc, e1.copy(), e1DotProp_op_e2);

                result = setterCall.expressionSemantic(sc);
            }
            else
            {
                // Create expression `_e1.prop`
                auto _e1 = new Identifier("_e1");
                Expression _e1DotProp = null;
                if (e1.op == TOK.dotIdentifier)
                {
                    auto e1_dotId = cast(DotIdExp)e1;
                    auto _e1Id = new IdentifierExp(e.loc, _e1);
                    _e1DotProp = new DotIdExp(e.loc, _e1Id, e1_dotId.ident);
                }
                else
                {
                    assert(false);  // Expression was not handled
                }

                // Create expression `_e1.prop()`
                auto getterCall = new CallExp(e.loc, _e1DotProp);

                // Create expression `_e1.prop() @ e2`
                auto _e1DotProp_op_e2 = createOperation(getterCall);

                // create expression `_e1.prop(_e1.prop() @ e2)`
                auto setterCall = new CallExp(e.loc, _e1DotProp, _e1DotProp_op_e2);

                // wrap setter in lambda expression
                // ********************************

                auto idType = Identifier.generateId("__T");
                auto idparamType = new TypeIdentifier(e.loc, idType);
                auto params = new Parameters();
                auto param = new Parameter(STC.auto_ | STC.ref_, idparamType, _e1, null, null);
                params.push(param);

                // need to wrap in a template declaration or compiler throws unknown identifier
                // error for idType
                auto tplParams = new TemplateParameters();
                tplParams.push(new TemplateTypeParameter(e.loc, idType, null, null));

                auto typeFunc = TypeFunction.create(params, null, 0, LINK.default_);
                auto fd = new FuncLiteralDeclaration(e.loc, e.loc, typeFunc, TOK.reserved, null);
                fd.fbody = new ReturnStatement(e.loc, setterCall);

                auto declSyms = new Dsymbols();
                declSyms.push(fd);
                auto td = new TemplateDeclaration(fd.loc, fd.ident, tplParams, null, declSyms, false, true);

                auto expFunc = new FuncExp(e.loc, td);

                // Create parameter `e1` for lambda expression
                auto exps = new Expressions();
                if (e1.op == TOK.dotIdentifier)
                {
                    auto expDotId = cast(DotIdExp)e1;
                    exps.push(expDotId.e1);
                }
                else if (e1.op == TOK.dotVariable)
                {
                    auto expDotVar = cast(DotVarExp)e1;
                    exps.push(expDotVar.e1);
                }
                else
                {
                    assert(false); // expression type not handled
                }

                // create expression ((auto ref _e1) => _e1.prop(_e1.prop() @ e2))(e1)
                auto lambdaCall = new CallExp(e.loc, expFunc, exps);

                result = lambdaCall.expressionSemantic(sc);
            }

            // if result is null, we still need to set e.e1 and e.e2 at the end of this function
            if (result)
            {
                return result;
            }
        }
    }

    e.e1 = e1x;
    e.e2 = e2x;
    return null;
}
Expression SemanticProp(PostExp e, Scope* sc)
{

    // This will convert id expressions to var expressions
    Expression e1x = e.e1.expressionSemantic(sc);
    Expression e2x = e.e2.expressionSemantic(sc);

    if (e1x.op == TOK.error)
        return e1x;
    if (e2x.op == TOK.error)
        return e2x;

    // This will convert a var expression to a call expression
    e1x = resolveProperties(sc, e1x);
    e2x = resolveProperties(sc, e2x);
    if (e1x.op == TOK.error)
        return e1x;
    if (e2x.op == TOK.error)
        return e2x;

    // Check for property assignment.
    // https://issues.dlang.org/show_bug.cgi?id=8006
    if (e1x.op == TOK.call)
    {
        Expression result = null;

        /* Rewrite e1++ as:
        * (auto tmp = e1, ++e1, tmp)
        */
        auto tmp = copyToTemp(0, "__pitmp", e1x);
        Expression ea = new DeclarationExp(e.loc, tmp);

        Expression eb = null;
        if (e.op == TOK.plusPlus)
            eb = SemanticProp(new AddAssignExp(e.loc, e.e1, IntegerExp.literal!1), sc);
        else
            eb = SemanticProp(new MinAssignExp(e.loc, e.e1, IntegerExp.literal!1), sc);
        //printf("eb: %s \n", eb.toChars());

        Expression ec = new VarExp(e.loc, tmp);

        // Combine de,ea,eb,ec
        Expression e1;
        e1 = new CommaExp(e.loc, ea, eb);
        e1 = new CommaExp(e.loc, e1, ec);
        //printf("%s", e1.toChars());
        e1 = e1.expressionSemantic(sc);
        //printf("%s", e1.toChars());
        result = e1;
        return result;
    }

    e.e1 = e1x;
    e.e2 = e2x;
    return null;
}
