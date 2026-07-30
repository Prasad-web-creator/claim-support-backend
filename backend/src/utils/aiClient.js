/**
 * AI Client
 * Helper for making reliable requests to Gemini, parsing JSON, and handling retries.
 */

const { GoogleGenerativeAI } = require("@google/generative-ai");
const logger = require('./logger');

/**
 * Aggressively parses and repairs AI-generated JSON.
 */
function parseAiJsonResponse(text) {
    if (!text) throw new Error('AI returned an empty response.');
    
    let cleanText = text.trim();
    
    // Attempt to extract JSON if wrapped in markdown or conversational text
    const firstBrace = cleanText.indexOf('{');
    const firstBracket = cleanText.indexOf('[');
    
    // Find the earliest starting JSON character
    let startIndex = -1;
    if (firstBrace !== -1 && firstBracket !== -1) {
        startIndex = Math.min(firstBrace, firstBracket);
    } else if (firstBrace !== -1) {
        startIndex = firstBrace;
    } else if (firstBracket !== -1) {
        startIndex = firstBracket;
    }

    if (startIndex !== -1) {
        cleanText = cleanText.substring(startIndex);
    }

    // Strip trailing markdown if present
    if (cleanText.endsWith('```')) {
        const lastTicks = cleanText.lastIndexOf('```');
        if (lastTicks > 0) {
            cleanText = cleanText.substring(0, lastTicks).trim();
        }
    }
    
    // Common hallucination: trailing commas before closing braces
    cleanText = cleanText.replace(/,\s*([\]}])/g, '$1');

    try {
        return JSON.parse(cleanText);
    } catch (error) {
        throw new Error('Failed to parse AI JSON response: ' + error.message + ' | Raw text redacted for security');
    }
}

/**
 * Extracts structured JSON using Gemini API with automatic retry on failure and exponential backoff.
 * 
 * @param {string} systemPrompt 
 * @param {string} userContent 
 * @param {string} modelName 
 * @param {number} maxTokens 
 * @returns {Promise<{ extractedJson: object, tokens: object, retryCount: number, processingTimeMs: number }>}
 */
async function extractJsonWithRetry(systemPrompt, userContent, modelName = process.env.AI_MODEL || 'gemini-2.5-flash', maxTokens = 4000, abortSignal = null) {
    const geminiApiKey = process.env.GEMINI_API_KEY;
    if (!geminiApiKey) {
        throw new Error('GEMINI_API_KEY is not defined in environment variables.');
    }

    const startTime = Date.now();
    let retryCount = 0;
    const maxRetries = 3;

    // Enforce "JSON" in prompt to help guide the model
    let enforcedPrompt = systemPrompt;
    if (!enforcedPrompt.toLowerCase().includes('json')) {
        enforcedPrompt += "\n\nYou MUST return your answer in valid JSON format.";
    }

    const genAI = new GoogleGenerativeAI(geminiApiKey);
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
            // Strict prompt engineering on retry
            let currentPrompt = enforcedPrompt;
            if (retryCount > 0) {
                currentPrompt += "\n\nCRITICAL RETRY INSTRUCTION: Your previous response was invalid. You MUST return ONLY valid JSON. No markdown, no explanations.";
                if (lastError && lastError.message) {
                    currentPrompt += `\n\nThe parser failed with this error: ${lastError.message}. Fix the JSON structure.`;
                }
            }
            
            const model = genAI.getGenerativeModel({
                model: modelName,
                systemInstruction: currentPrompt,
                generationConfig: {
                    responseMimeType: "application/json",
                    temperature: 0.1,
                    maxOutputTokens: maxTokens
                }
            });

            const result = await model.generateContent(userContent, { signal: activeSignal });
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
                    totalTokens: usage.totalTokenCount || 0
                },
                retryCount,
                processingTimeMs
            };

        } catch (error) {
            lastError = error;
            retryCount++;
            
            logger.error(`[AI Client] Attempt ${retryCount} failed: ${error.message}`, { stack: error.stack });
            
            if (retryCount <= maxRetries) {
                // Exponential Backoff with Jitter: 2s, 4s, 8s... + up to 1s random jitter
                let delayMs = (Math.pow(2, retryCount) * 1000) + (Math.random() * 1000); 
                
                // If explicit rate limit (429)
                if (error.message.includes('429')) {
                    delayMs = Math.max(delayMs, 5000); // Wait at least 5s for 429
                }
                
                logger.warn(`[AI Client] Backing off for ${Math.round(delayMs)}ms...`);
                await new Promise(resolve => setTimeout(resolve, delayMs));
            }
        }
    }

    throw new Error(`Extraction failed after ${maxRetries} retries. Last error: ${lastError.message}`);
}

module.exports = { extractJsonWithRetry };

