/** Pattern usefulness and exhaustiveness checking for switch expressions.
 *
 * The matrix owns only its initial rows. Recursive specialization passes row
 * indices and a column offset, so it never clones AST expressions or patterns.
 */
module dmd.decisiontree;

import dmd.dstruct;
import dmd.declaration;
import dmd.astenums;
import dmd.errorsink;
import dmd.expression;
import dmd.location;
import dmd.mtype;
import dmd.typesem;
import dmd.common.outbuffer;

private enum PatternKind : ubyte
{
    wildcard,
    constructor,
    literal,
}

private struct Pattern
{
    PatternKind kind;
    size_t value;
    Loc loc;
    bool isBool;
    Expression expr;
}

private struct MatrixRow
{
    Pattern[] columns;
    size_t armIndex;
}

private struct PatternMatrix
{
    MatrixRow[] rows;
    size_t numColumns;
}

private bool expressionsEqual(const(Expression) e1, const(Expression) e2)
{
    if (e1 is e2)
        return true;
    if (!e1 || !e2)
        return false;
    if (e1.op != e2.op)
        return false;
    if (auto ie1 = (cast()e1).isIntegerExp())
        if (auto ie2 = (cast()e2).isIntegerExp())
            return ie1.getInteger() == ie2.getInteger();
    if (auto re1 = (cast()e1).isRealExp())
        if (auto re2 = (cast()e2).isRealExp())
            return re1.value == re2.value;
    if (auto se1 = (cast()e1).isStringExp())
        if (auto se2 = (cast()e2).isStringExp())
            return se1.peekData() == se2.peekData();
    if ((cast()e1).isNullExp() && (cast()e2).isNullExp())
        return true;
    return e1.toString() == e2.toString();
}

private bool matches(ref const Pattern row, ref const Pattern value)
{
    if (row.kind == PatternKind.wildcard || value.kind == PatternKind.wildcard)
        return true;
    if (row.kind != value.kind)
        return false;
    if (row.expr || value.expr)
    {
        if (!row.expr || !value.expr)
            return false;
        return expressionsEqual(row.expr, value.expr);
    }
    return row.value == value.value;
}

private size_t constructorCount(EnumUnionDeclaration eu, size_t column, size_t[] fieldOffsets)
{
    if (column == 0)
        return eu.variants.length;
    return 0;
}

/*
 * Maranget's usefulness recurrence, represented as a borrowed view over the
 * original matrix. The root column is a finite enum-union constructor space;
 * bool fields are also finite. Integer fields use the literal/default split,
 * which represents all values not named in the matrix with one branch.
 */
private bool isUseful(ref const PatternMatrix matrix, size_t[] rowIndices,
    Pattern[] vector, size_t column, EnumUnionDeclaration eu, size_t[] fieldOffsets)
{
    if (!rowIndices.length)
        return true;
    if (column == matrix.numColumns)
        return false;

    const candidate = vector[column];
    const constructors = constructorCount(eu, column, fieldOffsets);
    if (candidate.kind == PatternKind.constructor || candidate.kind == PatternKind.literal)
    {
        size_t[] specialized;
        foreach (rowIndex; rowIndices)
            if (matches(matrix.rows[rowIndex].columns[column], candidate))
                specialized ~= rowIndex;
        return isUseful(matrix, specialized, vector, column + 1, eu, fieldOffsets);
    }

    if (constructors)
    {
        // <= 64 enum-union variants are tracked in one mask. The language
        // currently caps them at 256, so the larger case falls back to this
        // same bounded constructor iteration.
        ulong seen;
        foreach (rowIndex; rowIndices)
        {
            const pattern = matrix.rows[rowIndex].columns[column];
            if (pattern.kind == PatternKind.constructor && pattern.value < 64)
                seen |= 1UL << pattern.value;
        }
        foreach (constructor; 0 .. constructors)
        {
            Pattern specialized = Pattern(PatternKind.constructor, constructor, candidate.loc);
            size_t[] rows;
            foreach (rowIndex; rowIndices)
                if (matches(matrix.rows[rowIndex].columns[column], specialized))
                    rows ~= rowIndex;
            auto trial = vector.dup;
            trial[column] = specialized;
            if (isUseful(matrix, rows, trial, column + 1, eu, fieldOffsets))
                return true;
        }
        return false;
    }

    // A bool constructor space is finite even though it is represented by an
    // integer literal in the frontend AST.
    bool isBool;
    foreach (rowIndex; rowIndices)
    {
        const pattern = matrix.rows[rowIndex].columns[column];
        if (pattern.kind == PatternKind.literal && pattern.isBool)
            isBool = true;
    }
    if (isBool)
    {
        foreach (value; 0 .. 2)
        {
            Pattern literal = Pattern(PatternKind.literal, value, candidate.loc, true);
            size_t[] rows;
            foreach (rowIndex; rowIndices)
                if (matches(matrix.rows[rowIndex].columns[column], literal))
                    rows ~= rowIndex;
            auto trial = vector.dup;
            trial[column] = literal;
            if (isUseful(matrix, rows, trial, column + 1, eu, fieldOffsets))
                return true;
        }
        return false;
    }

    // Literal partitions: check each named point once, then the single
    // default interval that contains every other scalar value.
    foreach (rowIndex; rowIndices)
    {
        const literal = matrix.rows[rowIndex].columns[column];
        if (literal.kind != PatternKind.literal)
            continue;
        bool seen;
        foreach (previous; rowIndices)
        {
            if (previous == rowIndex)
                break;
            const other = matrix.rows[previous].columns[column];
            if (other.kind == PatternKind.literal && matches(other, literal))
            {
                seen = true;
                break;
            }
        }
        if (seen)
            continue;
        size_t[] rows;
        foreach (index; rowIndices)
            if (matches(matrix.rows[index].columns[column], literal))
                rows ~= index;
        auto trial = vector.dup;
        trial[column] = cast()literal;
        if (isUseful(matrix, rows, trial, column + 1, eu, fieldOffsets))
            return true;
    }
    size_t[] defaults;
    foreach (rowIndex; rowIndices)
        if (matrix.rows[rowIndex].columns[column].kind == PatternKind.wildcard)
            defaults ~= rowIndex;
    return isUseful(matrix, defaults, vector, column + 1, eu, fieldOffsets);
}

private MatrixRow makeRow(ref CaseExpArm arm, EnumUnionDeclaration eu, size_t[] fieldOffsets,
    size_t totalColumns, size_t armIndex)
{
    MatrixRow row;
    row.columns.length = totalColumns;
    foreach (ref pattern; row.columns)
        pattern = Pattern(PatternKind.wildcard, 0, arm.loc);
    row.armIndex = armIndex;
    if (arm.isDefault)
        return row;
    row.columns[0] = Pattern(PatternKind.constructor, arm.variantIndex, arm.loc);
    return row;
}

private void missingWitness(ref OutBuffer witness, ref const PatternMatrix matrix, size_t[] allRows,
    EnumUnionDeclaration eu, size_t[] fieldOffsets, size_t totalColumns, Loc loc)
{
    foreach (variantIndex, variant; eu.variants)
    {
        Pattern[] candidate = new Pattern[](totalColumns);
        foreach (ref pattern; candidate)
            pattern = Pattern(PatternKind.wildcard, 0, loc);
        candidate[0] = Pattern(PatternKind.constructor, variantIndex, loc);
        if (!isUseful(matrix, allRows, candidate, 0, eu, fieldOffsets))
            continue;
        if (variant.ident)
            witness.writestring(variant.ident.toString());
        else if (variant.payloadType && variant.payloadType.fields.length == 1)
            witness.writestring(variant.payloadType.fields[0].type.toChars());
        else
            witness.writestring("_");
        if (variant.payloadType && variant.payloadType.fields.length)
        {
            if (!variant.ident)
                return;
            witness.writeByte('(');
            foreach (index; 0 .. variant.payloadType.fields.length)
            {
                if (index)
                    witness.writestring(", ");
                witness.writeByte('_');
            }
            witness.writeByte(')');
        }
        return;
    }
    witness.writestring("_");
}

/** Check source-order usefulness and whether unguarded arms cover all cases. */
public bool checkExhaustivenessAndRedundancy(SwitchExp exp, EnumUnionDeclaration eu, ErrorSink eSink)
{
    size_t[] fieldOffsets;
    size_t totalColumns = 1;
    foreach (variant; eu.variants)
    {
        fieldOffsets ~= totalColumns;
        totalColumns += variant.payloadType ? variant.payloadType.fields.length : 0;
    }

    PatternMatrix matrix = PatternMatrix(null, totalColumns);
    bool hasDefault;
    foreach (armIndex, ref arm; exp.arms)
    {
        if (arm.isDefault)
        {
            Pattern[] wildcard = new Pattern[](totalColumns);
            foreach (ref pattern; wildcard)
                pattern = Pattern(PatternKind.wildcard, 0, arm.loc);
            size_t[] allRows;
            foreach (index; 0 .. matrix.rows.length)
                allRows ~= index;
            if (!isUseful(matrix, allRows, wildcard, 0, eu, fieldOffsets))
            {
                eSink.error(arm.loc, "redundant match arm; pattern is unreachable");
                return false;
            }
            hasDefault = true;
            continue;
        }
        size_t[] allRows;
        foreach (index; 0 .. matrix.rows.length)
            allRows ~= index;
        auto row = makeRow(arm, eu, fieldOffsets, totalColumns, armIndex);
        if (!isUseful(matrix, allRows, row.columns, 0, eu, fieldOffsets))
        {
            eSink.error(arm.loc, "redundant match arm; pattern is unreachable");
            return false;
        }
        if (!arm.guard)
            matrix.rows ~= row;
    }

    if (hasDefault)
        return true;

    Pattern[] wildcard = new Pattern[](totalColumns);
    foreach (ref pattern; wildcard)
        pattern = Pattern(PatternKind.wildcard, 0, exp.loc);
    size_t[] allRows;
    foreach (index; 0 .. matrix.rows.length)
        allRows ~= index;
    if (isUseful(matrix, allRows, wildcard, 0, eu, fieldOffsets))
    {
        OutBuffer witness;
        missingWitness(witness, matrix, allRows, eu, fieldOffsets, totalColumns, exp.loc);
        eSink.error(exp.loc, "switch expression is not exhaustive; missing pattern `%s`",
            witness.peekChars());
        return false;
    }
    return true;
}
