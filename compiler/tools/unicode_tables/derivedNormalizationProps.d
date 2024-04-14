module unicode_tables.derivedNormalizationProps;
import unicode_tables.util;

ValueRanges isCharacterNotNormalized;

void parseDerivedNormalizationProps(string dataFile)
{
    import std.algorithm : countUntil, splitter;
    import std.string : strip, lineSplitter;
    import std.conv : parse;
    import std.file : readText;

    string inputText = readText(dataFile);
    ValueRanges maybes, nos;

    ValueRange valueRangeFromString(string charRangeStr)
    {
        ValueRange ret;

        ptrdiff_t offsetOfSeperator = charRangeStr.countUntil("..");
        if (offsetOfSeperator < 0)
        {
            ret.start = parse!uint(charRangeStr, 16);
            ret.end = ret.start;
        }
        else
        {
            string startStr = charRangeStr[0 .. offsetOfSeperator],
                endStr = charRangeStr[offsetOfSeperator + 2 .. $];
            ret.start = parse!uint(startStr, 16);
            ret.end = parse!uint(endStr, 16);
        }

        return ret;
    }

    void handleLine(ValueRange valueRange, string propertyStr, string yesNoMaybeStr)
    {
        switch (propertyStr)
        {
        case "NFC_QC":
            // normalization form C, quick check value
            break;
        case "NFD_QC":
        case "NFKD_QC":
        case "NFKC_QC":
            // not interested in these for UAX31
            return;

        default:
            return;
        }

        switch (yesNoMaybeStr)
        {
        case "Y":
            assert(0); // As of Unicode 15.1.0 there are no yes entries.
        case "N":
            nos.add(valueRange);
            break;
        case "M":
            maybes.add(valueRange);
            break;
        default:
            return;
        }
    }

    foreach (line; inputText.lineSplitter)
    {
        ptrdiff_t offset;

        offset = line.countUntil('#');
        if (offset >= 0)
            line = line[0 .. offset];
        line = line.strip;

        if (line.length < 5) // anything that low can't represent a functional line
            continue;

        offset = line.countUntil(';');
        if (offset < 0) // no char range
            continue;
        string charRangeStr = line[0 .. offset].strip;
        line = line[offset + 1 .. $].strip;

        ValueRange valueRange = valueRangeFromString(charRangeStr);

        offset = line.countUntil(';');
        string propertyStr;

        if (offset > 0)
        {
            propertyStr = line[0 .. offset].strip;
            line = line[offset + 1 .. $].strip;
        }
        else
            propertyStr = line.strip;

        if (line.length > 0)
            handleLine(valueRange, propertyStr, line);
    }

    isCharacterNotNormalized = maybes.merge(nos);
}
