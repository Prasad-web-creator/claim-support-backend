/**
 * @fileoverview DocumentExtractionService handles Stages 1 & 2 of the pipeline:
 * Document Input and Local PDF Text Extraction Cascade.
 *
 * Now enhanced with multi-format support:
 *   - PDF (native text + scanned fallback via vision API)
 *   - Image (PNG, JPG, JPEG) via Gemini vision API OCR
 *   - DOCX via mammoth text extraction
 */

const mongoose = require('mongoose');
const pdfParse = require('pdf-parse');
const mammoth = require('mammoth');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');
const { Worker } = require('worker_threads');
const { extractJsonMultimodal } = require('../utils/multimodalAiClient');
const AppError = require('../utils/AppError');

// Image MIME types that require vision-based OCR
const IMAGE_MIMES = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp', 'image/bmp', 'image/tiff'];

// DOCX MIME type
const DOCX_MIME = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

// Vision OCR system prompt — used for image and scanned PDF extraction
const VISION_OCR_PROMPT = `You are an expert document OCR and text extraction system.

Extract ALL visible text from this document image, preserving:
- Tables (render as structured text)
- Bullet points and numbered lists
- Paragraphs and headings
- Key-value pairs
- Dates and currency values
- Policy numbers and medical codes
- Signatures (note "Signature present" if detected)
- Stamps (note "Stamp present" if detected)

Return the extracted content as a JSON object:
{
  "extractedText": "<the full extracted text, preserving structure as much as possible>",
  "hasSignature": false,
  "hasStamp": false,
  "pageCount": 1,
  "language": "English"
}

Preserve document structure. Do NOT summarize. Extract everything visible.`;

/**
 * Validates the extracted text to ensure it is human-readable and contains relevant data,
 * not just raw binary PDF object definitions or garbage.
 */
function validateExtractedText(text, diagnosticReport) {
  if (!text) {
    return { isValid: false, reason: 'Extracted text is empty.' };
  }
  if (text.length < 100) {
    return { isValid: false, reason: `Text length (${text.length}) is below the minimum threshold of 100 characters.` };
  }

  // Check for minimum alphabetic words to filter out pure numerical or binary dumps
  const words = text.match(/[A-Za-z]{3,}/g) || [];
  diagnosticReport.wordCount = words.length;
  
  const sentences = text.match(/[^.!?]+[.!?]+/g) || [];
  diagnosticReport.sentenceCount = sentences.length;
  
  const alphabeticChars = (text.match(/[A-Za-z]/g) || []).length;
  const printableChars = (text.match(/[\x20-\x7E]/g) || []).length;
  
  diagnosticReport.alphabetRatio = (alphabeticChars / text.length).toFixed(2);
  diagnosticReport.printableRatio = (printableChars / text.length).toFixed(2);

  if (words.length < 10) {
    return { isValid: false, reason: 'Text contains too few readable alphabetic words.' };
  }

  // Strict check against raw PDF structural keywords leaking into text
  const pdfKeywords = ['obj', 'endobj', 'stream', 'endstream', 'xref', 'trailer', '%%EOF', 'ReportLab Generated'];
  let garbageCount = 0;
  for (const kw of pdfKeywords) {
      if (text.includes(kw)) garbageCount++;
  }
  // If we see multiple structural keywords, it's highly likely we parsed raw binary bytes
  if (garbageCount >= 2) {
    return { isValid: false, reason: 'Text contains raw PDF object structures or binary symbols.' };
  }

  // Medical / Insurance context check
  const contextualKeywords = [
    'patient', 'diagnosis', 'medicine', 'hospital', 'policy', 'coverage', 
    'insurance', 'treatment', 'waiting', 'premium', 'hospitalization', 
    'name', 'age', 'gender', 'date', 'cost', 'doctor', 'clinic', 'claim'
  ];
  const lowerText = text.toLowerCase();
  const hasKeyword = contextualKeywords.some(kw => lowerText.includes(kw));
  
  if (!hasKeyword) {
    return { isValid: false, reason: 'Text does not contain any expected medical or insurance keywords.' };
  }

  return { isValid: true };
}

/**
 * Fallback Parser 1: pdfjs-dist
 */
async function extractWithPdfJsDist(buffer) {
  const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.mjs');
  const path = require('path');
  let standardFontDataUrl = path.join(__dirname, '../../node_modules/pdfjs-dist/standard_fonts/');
  standardFontDataUrl = standardFontDataUrl.replace(/\\/g, '/');
  if (!standardFontDataUrl.endsWith('/')) {
      standardFontDataUrl += '/';
  }
  
  const uint8Array = new Uint8Array(buffer);
  const loadingTask = pdfjsLib.getDocument({ 
    data: uint8Array,
    standardFontDataUrl: standardFontDataUrl 
  });
  const pdfDocument = await loadingTask.promise;
  
  let fullText = '';
  for (let i = 1; i <= pdfDocument.numPages; i++) {
      const page = await pdfDocument.getPage(i);
      const textContent = await page.getTextContent();
      const pageText = textContent.items.map(item => item.str).join(' ');
      fullText += pageText + '\n';
  }
  return { text: fullText, pageCount: pdfDocument.numPages };
}

/**
 * Fallback Parser 2: pdf2json
 */
function extractWithPdf2Json(buffer) {
  const PDFParser = require("pdf2json");
  return new Promise((resolve, reject) => {
      const pdfParser = new PDFParser(null, 1);
      pdfParser.on("pdfParser_dataError", errData => reject(new Error(errData.parserError)));
      pdfParser.on("pdfParser_dataReady", pdfData => {
          resolve({ text: pdfParser.getRawTextContent(), pageCount: pdfData.Pages.length });
      });
      pdfParser.parseBuffer(buffer);
  });
}



/**
 * Extract text from an image buffer using Gemini vision API.
 * @param {Buffer} buffer - Image buffer
 * @param {string} mimeType - e.g. 'image/png', 'image/jpeg'
 * @returns {Promise<{ text: string, pageCount: number }>}
 */
async function extractFromImageViaVision(buffer, mimeType) {
  const resolvedMime = mimeType === 'image/jpg' ? 'image/jpeg' : mimeType;


  const { extractedJson } = await extractJsonMultimodal(
    VISION_OCR_PROMPT,
    '',
    [{ mimeType: resolvedMime, data: buffer }]
  );

  return {
    text: extractedJson.extractedText || '',
    pageCount: extractedJson.pageCount || 1,
  };
}

/**
 * Extract text from a scanned PDF buffer using Gemini vision API.
 * Gemini natively supports PDF as inline data.
 * @param {Buffer} buffer - PDF buffer
 * @returns {Promise<{ text: string, pageCount: number }>}
 */
async function extractFromScannedPdfViaVision(buffer) {


  const { extractedJson } = await extractJsonMultimodal(
    VISION_OCR_PROMPT,
    '',
    [{ mimeType: 'application/pdf', data: buffer }]
  );

  return {
    text: extractedJson.extractedText || '',
    pageCount: extractedJson.pageCount || 1,
  };
}

/**
 * Extract text from a DOCX buffer using mammoth.
 * @param {Buffer} buffer - DOCX buffer
 * @returns {Promise<{ text: string, pageCount: number }>}
 */
async function extractFromDocx(buffer) {

  const result = await mammoth.extractRawText({ buffer });
  return {
    text: result.value || '',
    pageCount: 1,
  };
}

/**
 * Detect the actual file type from magic bytes.
 */
function detectFileType(buffer) {
  if (buffer.length < 4) return 'unknown';

  if (buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4E && buffer[3] === 0x47) return 'image/png';
  if (buffer[0] === 0xFF && buffer[1] === 0xD8 && buffer[2] === 0xFF) return 'image/jpeg';
  if (buffer[0] === 0x47 && buffer[1] === 0x49 && buffer[2] === 0x46) return 'image/gif';
  if (buffer.toString('utf8', 0, 5) === '%PDF-') return 'application/pdf';
  if (buffer[0] === 0x50 && buffer[1] === 0x4B && buffer[2] === 0x03 && buffer[3] === 0x04) return 'docx-or-zip';
  
  return 'unknown';
}

/**
 * Extracts text from a document stored in GridFS.
 * Now supports PDF (native + scanned), Image (PNG/JPG/JPEG), and DOCX files.
 */
async function extractDocument(gridFsFileId) {
  const diagnosticReport = {
      upload: true, storage: true, retrieval: false, sha256Match: false,
      pdfHeader: false, pdfEof: false, parserUsed: null, parserStatus: 'FAILED', failureReason: null
  };


  if (!gridFsFileId) throw new AppError('File ID is required for document extraction.', 400);
  if (!mongoose.connection || mongoose.connection.readyState !== 1) throw new AppError('Database connection is not established.', 500);

  const db = mongoose.connection.db;
  const bucket = new mongoose.mongo.GridFSBucket(db);
  const objectId = new mongoose.Types.ObjectId(gridFsFileId);

  // Retrieve file metadata
  let fileInfo;
  try {
    const files = await bucket.find({ _id: objectId }).toArray();
    if (!files || files.length === 0) throw new AppError(`File not found in GridFS with ID: ${gridFsFileId}`, 404);
    fileInfo = files[0];
  } catch (error) {
    diagnosticReport.failureReason = `Failed to retrieve file info: ${error.message}`;

    throw new AppError(`Failed to retrieve file info: ${error.message}`, 500);
  }

  const contentType = (fileInfo.contentType || '').toLowerCase();

  // --- STEP 3: Download buffer from GridFS ---
  let buffer;
  try {
    buffer = await new Promise((resolve, reject) => {
      const downloadStream = bucket.openDownloadStream(objectId);
      const chunks = [];
      downloadStream.on('data', chunk => chunks.push(chunk));
      downloadStream.on('error', err => reject(new Error(`Failed to read stream: ${err.message}`)));
      downloadStream.on('end', () => resolve(Buffer.concat(chunks)));
    });
    diagnosticReport.retrieval = true;
  } catch (error) {
    diagnosticReport.failureReason = `Buffer download failed - ${error.message}`;

    throw new AppError(`PDF_EXTRACTION_FAILED: Buffer download failed - ${error.message}`, 500);
  }

  const retrievedSize = buffer.length;
  const retrievedSha256 = crypto.createHash('sha256').update(buffer).digest('hex');

  if (fileInfo.metadata && fileInfo.metadata.sha256) {
      if (retrievedSha256 !== fileInfo.metadata.sha256) {
          diagnosticReport.failureReason = 'Hash mismatch between uploaded and retrieved buffer.';

          throw new AppError('GRIDFS_DATA_MISMATCH', 500);
      } else {
          diagnosticReport.sha256Match = true;
      }
  } else {
      // Legacy files without metadata hashes
      diagnosticReport.sha256Match = true; 
  }

  // --- Detect actual file type from magic bytes ---
  const detectedType = detectFileType(buffer);
  const isImage = IMAGE_MIMES.includes(contentType) || IMAGE_MIMES.includes(detectedType);
  const isDocx = contentType === DOCX_MIME || contentType.includes('wordprocessingml') || detectedType === 'docx-or-zip';
  const startsWithPdf = detectedType === 'application/pdf';

  diagnosticReport.pdfHeader = startsWithPdf;

  // --- Save Debug Copy ---
  if (process.env.NODE_ENV !== 'production') {
      try {
          const debugDir = path.join(__dirname, '../../debug');
          if (!fs.existsSync(debugDir)) {
              fs.mkdirSync(debugDir, { recursive: true });
          }
          const ext = isImage ? (detectedType === 'image/png' ? '.png' : '.jpg') : isDocx ? '.docx' : '.pdf';
          const debugPath = path.join(debugDir, `retrieved-${gridFsFileId}${ext}`);
          fs.writeFileSync(debugPath, buffer);
        } catch (debugErr) {
          logger.warn(`[DocumentExtractionService] Failed to save debug copy: ${debugErr.message}`);
        }
  }

  let text = '';
  let pageCount = 0;
  let usedLibrary = 'none';

  // ─── Route 1: IMAGE → Vision API OCR ────────────────────────────────────
  if (isImage) {

    try {
      const mimeForVision = detectedType !== 'unknown' ? detectedType : contentType;
      const result = await extractFromImageViaVision(buffer, mimeForVision);
      text = result.text;
      pageCount = result.pageCount;
      usedLibrary = 'gemini-vision-ocr';
      diagnosticReport.parserUsed = 'gemini-vision-ocr';
      diagnosticReport.parserStatus = 'SUCCESS';
    } catch (err) {
      diagnosticReport.failureReason = `Vision API OCR failed: ${err.message}`;

      throw new AppError(`IMAGE_EXTRACTION_FAILED: ${err.message}`, 500);
    }

  // ─── Route 2: DOCX → Mammoth Text Extraction ───────────────────────────
  } else if (isDocx) {

    try {
      const result = await extractFromDocx(buffer);
      text = result.text;
      pageCount = result.pageCount;
      usedLibrary = 'mammoth';
      diagnosticReport.parserUsed = 'mammoth';
      diagnosticReport.parserStatus = 'SUCCESS';
    } catch (err) {
      diagnosticReport.failureReason = `DOCX extraction failed: ${err.message}`;

      throw new AppError(`DOCX_EXTRACTION_FAILED: ${err.message}`, 500);
    }

  // ─── Route 3: PDF → Local Cascade + Vision Fallback ─────────────────────
  } else if (startsWithPdf) {
    // CASCADE EXTRACTION PIPELINE for native PDFs
    const extractionAttempts = [
      {
        name: 'pdf-parse',
        extract: () => {
          return new Promise((resolve, reject) => {
            const worker = new Worker(path.join(__dirname, 'pdfWorker.js'), { workerData: buffer });
            const timeoutId = setTimeout(() => {
              worker.terminate();
              reject(new Error('pdf-parse timeout'));
            }, 10000);
            
            worker.on('message', (message) => {
              clearTimeout(timeoutId);
              if (message.success) resolve({ text: message.text, pageCount: -1 });
              else reject(new Error(message.error));
            });
            worker.on('error', (err) => {
              clearTimeout(timeoutId);
              reject(err);
            });
            worker.on('exit', (code) => {
              if (code !== 0) {
                clearTimeout(timeoutId);
                reject(new Error(`Worker stopped with exit code ${code}`));
              }
            });
          });
        }
      },
      {
        name: 'pdfjs-dist',
        extract: async () => await extractWithPdfJsDist(buffer)
      },
      {
        name: 'pdf2json',
        extract: async () => await extractWithPdf2Json(buffer)
      }
    ];

    let extractedSuccessfully = false;

    for (const attempt of extractionAttempts) {
      const startTime = Date.now();
      
      try {
        const result = await attempt.extract();
        const duration = Date.now() - startTime;
        
        // Validate the extracted text
        const validation = validateExtractedText(result.text, diagnosticReport);
        
        if (validation.isValid) {
          text = result.text;
          pageCount = result.pageCount || 1;
          usedLibrary = attempt.name;
          extractedSuccessfully = true;
          diagnosticReport.parserUsed = attempt.name;
          diagnosticReport.parserStatus = 'SUCCESS';
          break; // Stop cascade on first successful and validated extraction
        } else {
          logger.warn(`[DocumentExtractionService] ⚠️ Extraction with ${attempt.name} succeeded, but validation failed: ${validation.reason}`);
          continue;
        }
        if (!diagnosticReport.failureReason) diagnosticReport.failureReason = validation.reason;
        
      } catch (err) {
        const duration = Date.now() - startTime;
        logger.warn(`[DocumentExtractionService] ⚠️ Extraction with ${attempt.name} failed after ${duration}ms: ${err.message}`, { stack: err.stack });
        if (!diagnosticReport.failureReason) diagnosticReport.failureReason = err.message;
      }
    }

    // FALLBACK: If all local parsers failed, try Vision API (scanned PDF)
    if (!extractedSuccessfully) {
      logger.warn(`[DocumentExtractionService] ⚠️ All local PDF parsers failed. Falling back to Gemini Vision API for scanned PDF OCR.`);
      try {
        const result = await extractFromScannedPdfViaVision(buffer);
        text = result.text;
        pageCount = result.pageCount;
        usedLibrary = 'gemini-vision-scanned-pdf';
        extractedSuccessfully = true;
        diagnosticReport.parserUsed = 'gemini-vision-scanned-pdf';
        diagnosticReport.parserStatus = 'SUCCESS';
      } catch (visionErr) {
        logger.error(`[DocumentExtractionService] ❌ Vision API fallback also failed: ${visionErr.message}`, { stack: visionErr.stack });
        diagnosticReport.failureReason = `All extraction methods failed including Vision API: ${visionErr.message}`;

        throw new AppError('PDF_EXTRACTION_FAILED', 500);
      }
    }

  // ─── Route 4: Unknown → Try as UTF-8 text ──────────────────────────────
  } else {
    text = buffer.toString('utf8');
    pageCount = 1;
    usedLibrary = 'utf8-text';
  }



  diagnosticReport.failureReason = null; // Success!



  return {
    text,
    pageCount,
    fileInfo: {
      id: fileInfo._id.toString(),
      filename: fileInfo.filename,
      contentType: fileInfo.contentType || 'application/pdf',
      size: fileInfo.length
    }
  };
}

module.exports = { extractDocument };
