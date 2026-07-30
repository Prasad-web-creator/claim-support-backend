/**
 * @fileoverview DocumentClassificationService
 *
 * Stage: Classify Document
 *
 * Accepts either:
 *   - extracted text (for native PDFs / DOCX)
 *   - an inline buffer (for images / scanned PDFs) sent to the Gemini vision API
 *
 * Returns:
 *   { documentType: string, confidence: number }
 *
 * Supported classification labels:
 *   Insurance Policy | Medical Prescription | Medical Bill | Hospital Report |
 *   Claim Form | Invoice | Receipt | Identity Proof | Other
 */

const { extractJsonWithRetry } = require('../utils/aiClient');
const { extractJsonMultimodal } = require('../utils/multimodalAiClient');

const CLASSIFICATION_LABELS = [
  'Insurance Policy',
  'Medical Prescription',
  'Medical Bill',
  'Hospital Report',
  'Claim Form',
  'Invoice',
  'Receipt',
  'Identity Proof',
  'Other',
];

const SYSTEM_PROMPT = `You are a document classification expert.

Analyze the provided document and classify it into EXACTLY one of the following types:
${CLASSIFICATION_LABELS.map((l) => `- ${l}`).join('\n')}

Return ONLY a valid JSON object. No markdown, no explanations.

Output schema:
{
  "documentType": "<label from the list above>",
  "confidence": <float 0.0 to 1.0>,
  "reasoning": "<one sentence explanation>"
}`;

/**
 * Classify a document from its extracted text.
 * @param {string} text - Cleaned document text
 * @returns {Promise<{ documentType: string, confidence: number, reasoning: string }>}
 */
async function classifyDocumentFromText(text) {
  if (!text || text.trim().length < 20) {
    return { documentType: 'Other', confidence: 0.0, reasoning: 'Insufficient text for classification.' };
  }

  const snippet = text.substring(0, 4000); // Use first 4k chars for fast classification
  const { extractedJson } = await extractJsonWithRetry(SYSTEM_PROMPT, snippet);

  return {
    documentType: CLASSIFICATION_LABELS.includes(extractedJson.documentType)
      ? extractedJson.documentType
      : 'Other',
    confidence: typeof extractedJson.confidence === 'number' ? extractedJson.confidence : 0.5,
    reasoning: extractedJson.reasoning || '',
  };
}

/**
 * Classify a document from a raw binary buffer (image or PDF).
 * @param {Buffer} buffer
 * @param {string} mimeType - e.g. 'image/png', 'application/pdf'
 * @returns {Promise<{ documentType: string, confidence: number, reasoning: string }>}
 */
async function classifyDocumentFromBuffer(buffer, mimeType) {
  const { extractedJson } = await extractJsonMultimodal(
    SYSTEM_PROMPT,
    '',
    [{ mimeType, data: buffer }]
  );

  return {
    documentType: CLASSIFICATION_LABELS.includes(extractedJson.documentType)
      ? extractedJson.documentType
      : 'Other',
    confidence: typeof extractedJson.confidence === 'number' ? extractedJson.confidence : 0.5,
    reasoning: extractedJson.reasoning || '',
  };
}

module.exports = { classifyDocumentFromText, classifyDocumentFromBuffer, CLASSIFICATION_LABELS };
