/**
 * @fileoverview MultimodalAiClient
 *
 * Extends the core AI client to support multimodal requests.
 * Accepts text + optional inline binary data (images, PDFs, DOCX text)
 * and calls the Gemini vision/multimodal API.
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');
const logger = require('./logger');

/**
 * Aggressively parses and repairs AI-generated JSON.
 */
function parseAiJsonResponse(text) {
  if (!text) throw new Error('AI returned an empty response.');
  let cleanText = text.trim();

  const firstBrace = cleanText.indexOf('{');
  const firstBracket = cleanText.indexOf('[');
  let startIndex = -1;

  if (firstBrace !== -1 && firstBracket !== -1) {
    startIndex = Math.min(firstBrace, firstBracket);
  } else if (firstBrace !== -1) {
    startIndex = firstBrace;
  } else if (firstBracket !== -1) {
    startIndex = firstBracket;
  }

  if (startIndex !== -1) cleanText = cleanText.substring(startIndex);

  if (cleanText.endsWith('```')) {
    const lastTicks = cleanText.lastIndexOf('```');
    if (lastTicks > 0) cleanText = cleanText.substring(0, lastTicks).trim();
  }

  // Fix trailing commas before closing braces/brackets
  cleanText = cleanText.replace(/,\s*([\]}])/g, '$1');

  try {
    return JSON.parse(cleanText);
  } catch (error) {
    throw new Error(
      'Failed to parse AI JSON response: ' + error.message +
      ' | Raw text redacted for security'
    );
  }
}

/**
 * Sends a multimodal request to Gemini supporting inline binary data (images, PDFs).
 *
 * @param {string} systemPrompt    - System instruction text
 * @param {string} textContent     - Additional text to include in the user turn
 * @param {Array<{mimeType:string, data:Buffer}>} inlineParts - Binary parts (images / PDFs)
 * @param {string} [modelName]     - Gemini model to use
 * @param {number} [maxTokens]
 * @returns {Promise<{ extractedJson: object, tokens: object, retryCount: number, processingTimeMs: number }>}
 */
async function extractJsonMultimodal(
  systemPrompt,
  textContent = '',
  inlineParts = [],
  modelName = process.env.AI_VISION_MODEL || process.env.AI_MODEL || 'gemini-2.0-flash',
  maxTokens = 8192,
  abortSignal = null
) {
  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (!geminiApiKey) throw new Error('GEMINI_API_KEY is not defined in environment variables.');

  const startTime = Date.now();
  let retryCount = 0;
  const maxRetries = 3;

  let enforcedPrompt = systemPrompt;
  if (!enforcedPrompt.toLowerCase().includes('json')) {
    enforcedPrompt += '\n\nYou MUST return your answer in valid JSON format.';
  }

  const genAI = new GoogleGenerativeAI(geminiApiKey);

  const buildParts = () => {
    const parts = [];

    // Add inline binary parts (images / PDFs)
    for (const part of inlineParts) {
      parts.push({
        inlineData: {
          mimeType: part.mimeType,
          data: part.data.toString('base64'),
        },
      });
    }

    // Add any supplementary text
    if (textContent && textContent.trim()) {
      parts.push({ text: textContent });
    }

    return parts;
  };

  let lastError = null;

  while (retryCount <= maxRetries) {
    let internalAbortController = null;
    let activeSignal = abortSignal;

    if (!activeSignal) {
        internalAbortController = new AbortController();
        activeSignal = internalAbortController.signal;
        // 45 second strict timeout per request
        setTimeout(() => internalAbortController.abort('Gemini API timeout exceeded'), 45000).unref();
    }

    try {
      let currentPrompt = enforcedPrompt;
      if (retryCount > 0) {
          currentPrompt += '\n\nCRITICAL RETRY INSTRUCTION: Your previous response was invalid. Return ONLY valid JSON. No markdown, no explanations.';
          if (lastError && lastError.message) {
              currentPrompt += `\n\nThe parser failed with this error: ${lastError.message}. Fix the JSON structure.`;
          }
      }

      const model = genAI.getGenerativeModel({
        model: modelName,
        systemInstruction: currentPrompt,
        generationConfig: {
          responseMimeType: 'application/json',
          temperature: 0.1,
          maxOutputTokens: maxTokens,
        },
      });

      const result = await model.generateContent({
        contents: [{ role: 'user', parts: buildParts() }],
      }, { signal: activeSignal });
      
      const response = result.response;
      const content = response.text();
      const usage = response.usageMetadata || {};

      const extractedJson = parseAiJsonResponse(content);
      const processingTimeMs = Date.now() - startTime;



      return {
        extractedJson,
        tokens: {
          promptTokens: usage.promptTokenCount || 0,
          completionTokens: usage.candidatesTokenCount || 0,
          totalTokens: usage.totalTokenCount || 0,
        },
        retryCount,
        processingTimeMs,
      };
    } catch (error) {
      lastError = error;
      logger.error(`[MultimodalAI] ❌ Attempt ${retryCount + 1} failed: ${error.message}`, { stack: error.stack });
      retryCount++;

      if (retryCount <= maxRetries) {
        let delayMs = Math.pow(2, retryCount) * 1000 + Math.random() * 1000;
        if (error.message.includes('429')) {
          delayMs = Math.max(delayMs, 5000);
        }

        logger.warn(`[MultimodalAI] Backing off for ${Math.round(delayMs)}ms...`);
        await new Promise(res => setTimeout(res, delayMs));
      }
    }
  }

  throw new Error(`Multimodal extraction failed after ${maxRetries} retries. Last error: ${lastError.message}`);
}

module.exports = { extractJsonMultimodal };
