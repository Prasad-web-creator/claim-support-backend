const fs = require('fs');
const { PDFDocument } = require('pdf-lib');
const mammoth = require('mammoth');

/**
 * Perform deep structural validation of the file.
 * Throws an error if the file is structurally invalid.
 */
async function validateFileStructure(filePath, mimetype) {
  try {
    if (mimetype === 'application/pdf') {
      const pdfBytes = fs.readFileSync(filePath);
      const pdfDoc = await PDFDocument.load(pdfBytes, { ignoreEncryption: false });
      
      if (pdfDoc.isEncrypted) {
        throw new Error('PDF is encrypted or password protected');
      }
      
      const pageCount = pdfDoc.getPageCount();
      if (pageCount === 0) {
        throw new Error('PDF has no pages');
      }
    } else if (mimetype === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      // Mammoth extracts raw text from DOCX. If it's not a valid zip/docx, this will fail.
      const result = await mammoth.extractRawText({ path: filePath });
      if (!result) {
        throw new Error('Failed to parse DOCX structure');
      }
    }
    // Image validation is largely covered by the magic bytes in `uploadValidation.js`, 
    // but we can assume structural integrity if it passed magic bytes for our simple usecase.
    return true;
  } catch (error) {
    throw new Error(`Structural validation failed: ${error.message}`);
  }
}

module.exports = { validateFileStructure };
