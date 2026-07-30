/**
 * @fileoverview MultiFormatExtractionService
 *
 * Handles multi-format OCR and structured data extraction for:
 *   - PDF  (native text or scanned)
 *   - PNG / JPG / JPEG  (image OCR)
 *   - DOCX  (Word document)
 *
 * Extraction prompts are dynamically selected based on the document
 * classification returned by DocumentClassificationService.
 *
 * Always returns:
 * {
 *   documentType, confidence, metadata, extractedData, rawText, warnings, missingFields
 * }
 */

const mongoose = require('mongoose');
const pdfParse = require('pdf-parse');
const mammoth = require('mammoth');
const path = require('path');

const { extractJsonWithRetry } = require('../utils/aiClient');
const { extractJsonMultimodal } = require('../utils/multimodalAiClient');
const { classifyDocumentFromText, classifyDocumentFromBuffer } = require('./DocumentClassificationService');
const { Worker } = require('worker_threads');

// ─── Constants ────────────────────────────────────────────────────────────────

const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'image/png',
  'image/jpeg',
  'image/jpg',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
]);

const ALLOWED_EXTENSIONS = new Set(['.pdf', '.png', '.jpg', '.jpeg', '.docx']);

// Target roughly 25k characters per chunk to stay well within Gemini context limits
const CHUNK_SIZE = 25000;

// ─── Chunking & Merging Helpers ───────────────────────────────────────────────

function chunkText(text, maxChars = CHUNK_SIZE) {
  if (text.length <= maxChars) return [text];
  
  const chunks = [];
  const paragraphs = text.split(/\n\s*\n/); // split by paragraph
  
  let currentChunk = '';
  for (const p of paragraphs) {
    if (currentChunk.length + p.length > maxChars && currentChunk.length > 0) {
      chunks.push(currentChunk);
      currentChunk = '';
    }
    currentChunk += (currentChunk.length > 0 ? '\n\n' : '') + p;
  }
  
  if (currentChunk) chunks.push(currentChunk);
  return chunks;
}

function mergeChunkResults(results) {
  if (!results || results.length === 0) return {};
  if (results.length === 1) return results[0];
  
  const merged = {};
  
  for (const res of results) {
    for (const [key, value] of Object.entries(res)) {
      if (Array.isArray(value)) {
        if (!merged[key]) merged[key] = [];
        merged[key] = [...merged[key], ...value];
      } else if (typeof value === 'object' && value !== null) {
        if (!merged[key]) merged[key] = {};
        merged[key] = { ...merged[key], ...value };
      } else {
        // For primitives, keep the first non-null/empty value found
        if (!merged[key] || merged[key] === null || merged[key] === '') {
          merged[key] = value;
        }
      }
    }
  }
  
  return merged;
}

// ─── Mime Detection by Magic Bytes ────────────────────────────────────────────

/**
 * Detect file MIME type from magic bytes when the declared type is unreliable.
 */
function detectMimeFromBuffer(buffer) {
  if (buffer.length < 4) return null;

  // PNG: 89 50 4E 47
  if (buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4e && buffer[3] === 0x47)
    return 'image/png';

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff)
    return 'image/jpeg';

  // PDF: %PDF
  if (buffer.toString('utf8', 0, 4) === '%PDF')
    return 'application/pdf';

  // DOCX / ZIP: PK\x03\x04
  if (buffer[0] === 0x50 && buffer[1] === 0x4b && buffer[2] === 0x03 && buffer[3] === 0x04)
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  return null;
}

// ─── File Validation ──────────────────────────────────────────────────────────

/**
 * Validate extension and MIME type (including magic-byte check).
 * Returns { valid: boolean, mimeType: string, reason?: string }
 */
function validateFile(originalFilename, declaredMimeType, buffer) {
  const ext = path.extname(originalFilename).toLowerCase();

  if (!ALLOWED_EXTENSIONS.has(ext)) {
    return {
      valid: false,
      reason: `Unsupported file extension "${ext}". Allowed: ${[...ALLOWED_EXTENSIONS].join(', ')}`,
    };
  }

  const detectedMime = detectMimeFromBuffer(buffer) || declaredMimeType;

  if (!ALLOWED_MIME_TYPES.has(detectedMime)) {
    return {
      valid: false,
      reason: `Unsupported file type "${detectedMime}". Allowed: PDF, PNG, JPG, JPEG, DOCX`,
    };
  }

  return { valid: true, mimeType: detectedMime };
}

// ─── Text Extraction Helpers ──────────────────────────────────────────────────

/**
 * Extract text from a native PDF buffer using a Worker thread.
 * Returns { text, pageCount, isNative }
 */
async function extractFromNativePdf(buffer) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(path.join(__dirname, '../workers/pdfWorker.js'));
    
    const timeout = setTimeout(() => {
      worker.terminate();
      reject(new Error('pdf-parse timeout (worker terminated)'));
    }, 15000);

    worker.on('message', (msg) => {
      clearTimeout(timeout);
      if (msg.success) {
        resolve({ text: msg.text || '', pageCount: msg.pageCount || 1, isNative: true });
      } else {
        reject(new Error(msg.error || 'Worker error'));
      }
      worker.terminate();
    });

    worker.on('error', (err) => {
      clearTimeout(timeout);
      reject(err);
      worker.terminate();
    });

    worker.on('exit', (code) => {
      clearTimeout(timeout);
      if (code !== 0) reject(new Error(`Worker stopped with exit code ${code}`));
    });

    worker.postMessage({ type: 'PARSE_PDF', data: buffer });
  });
}

/**
 * Extract text from a DOCX buffer using mammoth.
 * Also extracts embedded images and returns them for optional OCR.
 */
async function extractFromDocx(buffer) {
  const result = await mammoth.extractRawText({ buffer });
  const messages = result.messages || [];

  const warnings = messages
    .filter((m) => m.type === 'warning')
    .map((m) => m.message);

  return {
    text: result.value || '',
    pageCount: 1,
    warnings,
  };
}

// ─── Structured Extraction Prompts ───────────────────────────────────────────

const EXTRACTION_PROMPTS = {
  'Insurance Policy': `You are an expert insurance policy data extractor.
Extract ALL of the following fields from the document. Return ONLY valid JSON, no markdown.

Output schema:
{
  "insuranceCompany": "",
  "policyNumber": "",
  "policyHolder": "",
  "insuredName": "",
  "policyType": "",
  "policyStartDate": "",
  "policyEndDate": "",
  "coverageAmount": 0,
  "premiumAmount": 0,
  "waitingPeriodDays": 0,
  "roomEligibility": "",
  "deductible": "",
  "coPay": "",
  "coveredDiseases": [],
  "excludedDiseases": [],
  "coveredTreatments": [],
  "excludedTreatments": [],
  "networkHospitalRules": "",
  "preExistingDiseaseRules": "",
  "benefits": [],
  "specialConditions": []
}`,

  'Medical Prescription': `You are a medical prescription data extractor.
Extract ALL fields from this prescription. Return ONLY valid JSON, no markdown.

Output schema:
{
  "doctorName": "",
  "doctorLicense": "",
  "hospitalName": "",
  "patientName": "",
  "patientAge": "",
  "patientGender": "",
  "diagnosis": "",
  "prescriptionDate": "",
  "medicines": [
    { "name": "", "dosage": "", "frequency": "", "duration": "", "instructions": "" }
  ],
  "tests": [],
  "procedures": [],
  "followUpDate": "",
  "notes": ""
}`,

  'Medical Bill': `You are a medical billing data extractor.
Extract ALL fields from this bill. Return ONLY valid JSON, no markdown.

Output schema:
{
  "hospitalName": "",
  "invoiceNumber": "",
  "billDate": "",
  "patientName": "",
  "patientId": "",
  "totalAmount": 0,
  "taxAmount": 0,
  "discountAmount": 0,
  "netPayable": 0,
  "currency": "INR",
  "paymentMethod": "",
  "lineItems": [
    { "description": "", "quantity": 0, "unitPrice": 0, "total": 0 }
  ]
}`,

  'Hospital Report': `You are a medical report data extractor.
Extract ALL fields from this hospital report. Return ONLY valid JSON, no markdown.

Output schema:
{
  "hospitalName": "",
  "reportDate": "",
  "patientName": "",
  "patientId": "",
  "doctorName": "",
  "reportType": "",
  "diagnosis": "",
  "findings": "",
  "recommendations": "",
  "medications": [],
  "followUp": ""
}`,

  'Claim Form': `You are a claims processing data extractor.
Extract ALL fields from this claim form. Return ONLY valid JSON, no markdown.

Output schema:
{
  "claimNumber": "",
  "claimDate": "",
  "policyNumber": "",
  "patientName": "",
  "claimantName": "",
  "diagnosis": "",
  "admissionDate": "",
  "dischargeDate": "",
  "totalClaimAmount": 0,
  "hospitalName": "",
  "documents": [],
  "remarks": ""
}`,

  Invoice: `You are an invoice data extractor.
Extract ALL fields from this invoice. Return ONLY valid JSON, no markdown.

Output schema:
{
  "invoiceNumber": "",
  "vendorName": "",
  "vendorAddress": "",
  "invoiceDate": "",
  "dueDate": "",
  "totalAmount": 0,
  "taxAmount": 0,
  "currency": "",
  "lineItems": [
    { "description": "", "quantity": 0, "unitPrice": 0, "total": 0 }
  ]
}`,

  Receipt: `You are a receipt data extractor.
Extract ALL fields from this receipt. Return ONLY valid JSON, no markdown.

Output schema:
{
  "merchantName": "",
  "receiptNumber": "",
  "date": "",
  "totalAmount": 0,
  "taxAmount": 0,
  "currency": "",
  "paymentMethod": "",
  "items": []
}`,

  'Identity Proof': `You are an identity document data extractor.
Extract ALL fields from this document. Return ONLY valid JSON, no markdown.

Output schema:
{
  "documentType": "",
  "documentNumber": "",
  "fullName": "",
  "dateOfBirth": "",
  "gender": "",
  "address": "",
  "issuedBy": "",
  "issueDate": "",
  "expiryDate": ""
}`,

  Other: `You are a document data extractor.
Extract all meaningful structured information from this document. Return ONLY valid JSON, no markdown.

Output schema:
{
  "summary": "",
  "keyFields": {},
  "rawText": ""
}`,
};

// ─── Core Processing Pipeline ────────────────────────────────────────────────

/**
 * Process a file buffer through the full multi-format OCR & extraction pipeline.
 *
 * @param {Buffer} buffer                - Raw file buffer
 * @param {string} originalFilename      - e.g. "policy.pdf"
 * @param {string} declaredMimeType      - MIME type declared by the client
 * @returns {Promise<object>} Structured extraction result
 */
async function processDocument(buffer, originalFilename, declaredMimeType) {
  const startTime = Date.now();
  const warnings = [];

  // ── 1. Validate File ──────────────────────────────────────────────────────
  const validation = validateFile(originalFilename, declaredMimeType, buffer);
  if (!validation.valid) {
    throw new Error(`VALIDATION_ERROR: ${validation.reason}`);
  }

  const mimeType = validation.mimeType;
  const ext = path.extname(originalFilename).toLowerCase();
  let rawText = '';
  let pageCount = 1;
  let extractionMethod = 'unknown';

  // ── 2. Extract Text / Buffer ──────────────────────────────────────────────

  const isImage = mimeType === 'image/png' || mimeType === 'image/jpeg' || mimeType === 'image/jpg';
  const isPdf = mimeType === 'application/pdf';
  const isDocx = ext === '.docx';
  let useMultimodal = isImage;
  let inlineParts = [];

  if (isImage) {
    // Images go directly to vision API
    const resolvedMime = mimeType === 'image/jpg' ? 'image/jpeg' : mimeType;
    inlineParts = [{ mimeType: resolvedMime, data: buffer }];
    extractionMethod = 'vision-api';

  } else if (isPdf) {
    // Try native PDF text extraction first
    try {
      const result = await extractFromNativePdf(buffer);
      rawText = result.text;
      pageCount = result.pageCount;

      // If extracted text is insufficient, it's a scanned PDF → use vision API
      const wordCount = (rawText.match(/[A-Za-z]{3,}/g) || []).length;
      const wordsPerPage = wordCount / pageCount;
      
      if (wordsPerPage < 50 || wordCount < 50) {
        warnings.push('PDF appears to be scanned or low density. Using vision-based OCR.');
        inlineParts = [{ mimeType: 'application/pdf', data: buffer }];
        useMultimodal = true;
        extractionMethod = 'vision-api-scanned-pdf';
        rawText = '';
      } else {
        extractionMethod = 'native-pdf-text';
      }
    } catch (err) {
      warnings.push(`Native PDF extraction failed: ${err.message}. Using vision-based OCR.`);
      inlineParts = [{ mimeType: 'application/pdf', data: buffer }];
      useMultimodal = true;
      extractionMethod = 'vision-api-fallback';
    }

  } else if (isDocx) {
    try {
      const result = await extractFromDocx(buffer);
      rawText = result.text;
      pageCount = result.pageCount;
      warnings.push(...result.warnings);
      extractionMethod = 'docx-mammoth';
    } catch (err) {
      throw new Error(`DOCX_EXTRACTION_FAILED: ${err.message}`);
    }
  }

  // ── 3. Classify Document ─────────────────────────────────────────────────
  let classification;
  try {
    if (useMultimodal && inlineParts.length > 0) {
      classification = await classifyDocumentFromBuffer(inlineParts[0].data, inlineParts[0].mimeType);
    } else {
      classification = await classifyDocumentFromText(rawText);
    }
  } catch (err) {
    warnings.push(`Classification failed: ${err.message}. Defaulting to "Other".`);
    classification = { documentType: 'Other', confidence: 0.0, reasoning: 'Classification error.' };
  }



  // ── 4. Extract Structured Data ───────────────────────────────────────────
  const extractionPrompt = EXTRACTION_PROMPTS[classification.documentType] || EXTRACTION_PROMPTS['Other'];
  let extractedData = {};
  let missingFields = [];
  let retryCountTotal = 0;

  try {
    if (useMultimodal && inlineParts.length > 0) {
      const result = await extractJsonMultimodal(extractionPrompt, '', inlineParts);
      extractedData = result.extractedJson;
      retryCountTotal += result.retryCount || 0;
    } else {
      // Chunk text to avoid context limits and process in parallel
      const chunks = chunkText(rawText);
      const chunkPromises = chunks.map(chunk => extractJsonWithRetry(extractionPrompt, chunk));
      
      const chunkResults = await Promise.all(chunkPromises);
      
      const successfulJsons = chunkResults.map(res => {
        retryCountTotal += res.retryCount || 0;
        return res.extractedJson;
      });
      
      extractedData = mergeChunkResults(successfulJsons);
    }

    // Detect missing top-level fields (null or empty)
    missingFields = Object.entries(extractedData)
      .filter(([, v]) => v === null || v === '' || (Array.isArray(v) && v.length === 0))
      .map(([k]) => k);

  } catch (err) {
    warnings.push(`Structured extraction failed: ${err.message}`);
    extractedData = {};
  }

  // ── 5. Confidence Scoring ───────────────────────────────────────────────
  // Base confidence from classification
  let overallConfidence = classification.confidence || 0.5;
  
  // Deduct for extraction fallback
  if (extractionMethod === 'vision-api-fallback') overallConfidence -= 0.15;
  if (extractionMethod === 'vision-api-scanned-pdf') overallConfidence -= 0.1;
  
  // Deduct for AI retries (indicates model struggled with structure)
  overallConfidence -= (retryCountTotal * 0.05);
  
  // Deduct for missing required fields (if schema has many fields but many are empty)
  const totalKeys = Object.keys(extractedData).length;
  if (totalKeys > 0) {
    const missingRatio = missingFields.length / totalKeys;
    overallConfidence -= (missingRatio * 0.3); // up to 30% penalty
  }
  
  // Clamp between 0.1 and 0.99
  overallConfidence = Math.max(0.1, Math.min(0.99, overallConfidence));

  const processingTimeMs = Date.now() - startTime;

  // Securely log pipeline metrics (DO NOT LOG RAW TEXT OR JSON)


  return {
    documentType: classification.documentType,
    confidence: Number(overallConfidence.toFixed(2)),
    metadata: {
      pages: pageCount,
      language: 'English',
      fileType: ext.replace('.', '').toUpperCase(),
      mimeType,
      extractionMethod,
      processingTimeMs,
    },
    extractedData,
    rawText: rawText.substring(0, 2000), // Return a preview of raw text
    warnings,
    missingFields,
  };
}

module.exports = { processDocument, validateFile, ALLOWED_MIME_TYPES, ALLOWED_EXTENSIONS };
