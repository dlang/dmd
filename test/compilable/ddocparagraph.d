// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh paragraph

/**
 * $(DDOC_COMMENT Note: The use of a nonexistent <paragraph> tag is deliberate,
 * to make sure it comes from the expansion of DDOC_PARAGRAPH and not from
 * something else that happens to also use <p>.)
 *
 * Macros:
 * BR=<break>
 * DDOC_PARAGRAPH=<paragraph>$0</paragraph>
 */
module ddocparagraph;

/**
 * Function summary goes here. Should be in own paragraph outside any section.
 *
 * Function description goes here. Treated as first paragraph by ddoc.
 *
 * Another paragraph in function description.
 * Continues same paragraph. Should be within the same &lt;paragraph&gt; tag.
 *
 * Params:
 *  x = Parameter description with multiple paragraphs.
 *
 *      Second paragraph here.
 *  y = Parameter description in one paragraph.
 *
 * Section:
 * Single paragraph within section.
 *
 * Blank_section_should_have_no_paragraph_tags:
 *
 * Section_with_multiple_paragraphs:
 * First paragraph.
 *
 * Another paragraph.
 *
 * $(B Third) paragraph that starts with a macro.
 *
 *
 *
 *
 * Blank lines before this should have no extraneous paragraph tags.
 * ---
 * // Code blocks end any paragraphs in progress.
 *
 * exampleCode(2, 1); // interspersed blank line
 * ---
 * Paragraph following code block without blank line.
 *
 * ---
 * // Code block following blank line.
 * ---
 * Paragraph following code block without blank line.
 */
void exampleCode(int x, int y) { }
