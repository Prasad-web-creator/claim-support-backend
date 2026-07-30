const { parentPort } = require('worker_threads');
const pdfParse = require('pdf-parse');

parentPort.on('message', async (message) => {
  if (message.type === 'PARSE_PDF') {
    try {
      // Message payload should be a Uint8Array or Buffer.
      const buffer = Buffer.from(message.data);
      const pdfData = await pdfParse(buffer, { max: 0 });
      
      parentPort.postMessage({
        success: true,
        text: pdfData.text || '',
        pageCount: pdfData.numpages || 1
      });
    } catch (error) {
      parentPort.postMessage({
        success: false,
        error: error.message
      });
    }
  }
});
