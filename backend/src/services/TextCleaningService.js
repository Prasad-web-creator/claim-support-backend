/**
 * @fileoverview TextCleaningService handles Stage 3 of the pipeline:
 * Text Cleaning and Normalization.
 */

/**
 * Cleans and normalizes extracted raw text.
 * 
 * @param {string} rawText - The raw text extracted from the document.
 * @returns {string} The cleaned and normalized text string.
 */
function cleanText(rawText) {

  if (typeof rawText !== 'string') {
    return '';
  }

  let text = rawText;

  // 1. Remove invisible/control characters except standard whitespace (newlines, tabs)
  // \u0000-\u0008, \u000B-\u000C, \u000E-\u001F, \u007F-\u009F
  text = text.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/g, '');

  // Split into lines for line-by-line processing
  let lines = text.split('\n');
  const lineCountMap = new Map();

  // Trim each line and count occurrences for header/footer removal
  lines = lines.map(line => {
    const trimmed = line.trim();
    if (trimmed) {
      lineCountMap.set(trimmed, (lineCountMap.get(trimmed) || 0) + 1);
    }
    return trimmed;
  });

  // Patterns for page numbers
  const pageNumRegex = /^(page\s+\d+(\s+of\s+\d+)?|-\s*\d+\s*-|\d+\s*\/\s*\d+)$/i;

  const cleanedLines = [];

  for (const line of lines) {
    if (!line) {
      cleanedLines.push(''); // keep blank lines for now to normalize later
      continue;
    }

    // Remove repeated headers/footers (lines repeating 3 or more times)
    // Avoid removing long lines which are likely content and not headers/footers
    if (lineCountMap.get(line) >= 3 && line.length < 100) {
      continue;
    }

    // Remove page numbers
    if (pageNumRegex.test(line)) {
      continue;
    }

    // Remove duplicate spaces within the line
    const cleanedLine = line.replace(/[ \t]{2,}/g, ' ');
    cleanedLines.push(cleanedLine);
  }

  // Join lines back together
  let cleanedText = cleanedLines.join('\n');

  // Normalize line breaks: collapse 3+ newlines to exactly 2
  cleanedText = cleanedText.replace(/\n{3,}/g, '\n\n');

  // Final trim
  cleanedText = cleanedText.trim();


  return cleanedText;
}

module.exports = { cleanText };
