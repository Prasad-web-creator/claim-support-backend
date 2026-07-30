/**
 * Document Splitter
 * Intelligently chunks large text for AI context windows and merges results.
 */

function splitTextIntelligently(text, maxChars = 24000) {
    if (text.length <= maxChars) {
        return [text];
    }

    const chunks = [];
    let currentChunk = '';
    
    // Split by paragraphs to avoid cutting mid-sentence
    const paragraphs = text.split(/\n\s*\n/);
    
    for (const para of paragraphs) {
        if ((currentChunk.length + para.length + 2) > maxChars) {
            if (currentChunk.length > 0) {
                chunks.push(currentChunk);
                currentChunk = '';
            }
            // If a single paragraph is larger than maxChars, we just slice it
            if (para.length > maxChars) {
                let start = 0;
                while (start < para.length) {
                    chunks.push(para.substring(start, start + maxChars));
                    start += maxChars;
                }
            } else {
                currentChunk = para;
            }
        } else {
            currentChunk += (currentChunk ? '\n\n' : '') + para;
        }
    }
    
    if (currentChunk.length > 0) {
        chunks.push(currentChunk);
    }
    
    return chunks;
}

/**
 * Deep merge multiple extracted JSON objects.
 * Prioritizes non-null values. Merges arrays by concatenating and deduping.
 */
function mergeExtractedJson(jsons) {
    if (!jsons || jsons.length === 0) return {};
    if (jsons.length === 1) return jsons[0];

    const merged = {};
    const keys = new Set();
    
    // Collect all unique keys
    jsons.forEach(json => {
        if (json) Object.keys(json).forEach(k => keys.add(k));
    });

    for (const key of keys) {
        let isArray = false;
        const arrayValues = [];
        let finalPrimitive = null;

        for (const json of jsons) {
            if (!json) continue;
            const val = json[key];
            
            if (val !== null && val !== undefined && val !== '') {
                if (Array.isArray(val)) {
                    isArray = true;
                    arrayValues.push(...val);
                } else if (finalPrimitive === null) {
                    finalPrimitive = val;
                }
            }
        }

        if (isArray) {
            // Dedupe simple arrays (strings, numbers)
            if (arrayValues.length > 0 && typeof arrayValues[0] !== 'object') {
                merged[key] = [...new Set(arrayValues)];
            } else {
                // For arrays of objects (like medicines), deduping is harder. 
                // We'll deduplicate by JSON stringification for simplicity.
                const uniqueStrs = new Set(arrayValues.map(v => JSON.stringify(v)));
                merged[key] = Array.from(uniqueStrs).map(v => JSON.parse(v));
            }
        } else {
            merged[key] = finalPrimitive;
        }
    }

    return merged;
}

module.exports = { splitTextIntelligently, mergeExtractedJson };
