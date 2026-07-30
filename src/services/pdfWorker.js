const { parentPort, workerData } = require('worker_threads');
const pdf = require('pdf-parse');

async function parse() {
    try {
        const buffer = Buffer.from(workerData);
        const data = await pdf(buffer);
        parentPort.postMessage({ success: true, text: data.text });
    } catch (error) {
        parentPort.postMessage({ success: false, error: error.message });
    }
}

parse();
