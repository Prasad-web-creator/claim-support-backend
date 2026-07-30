const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

function TempDiskAndHashStorage(opts) {
  this.getDestination = opts.destination || function(req, file, cb) {
    cb(null, path.join(__dirname, '../../uploads/'));
  };
}

TempDiskAndHashStorage.prototype._handleFile = function(req, file, cb) {
  this.getDestination(req, file, (err, destPath) => {
    if (err) return cb(err);
    if (!fs.existsSync(destPath)) {
      fs.mkdirSync(destPath, { recursive: true });
    }

    crypto.randomBytes(16, (err, buf) => {
      if (err) return cb(err);
      
      const filename = buf.toString('hex') + path.extname(file.originalname);
      const finalPath = path.join(destPath, filename);
      
      const hash = crypto.createHash('sha256');
      const outStream = fs.createWriteStream(finalPath);
      
      file.stream.on('data', chunk => {
        hash.update(chunk);
      });
      
      outStream.on('error', cb);
      
      file.stream.pipe(outStream);
      
      outStream.on('finish', () => {
        cb(null, {
          destination: destPath,
          filename: filename,
          path: finalPath,
          size: outStream.bytesWritten,
          sha256: hash.digest('hex')
        });
      });
    });
  });
};

TempDiskAndHashStorage.prototype._removeFile = function(req, file, cb) {
  const filePath = file.path;
  if (filePath) {
    fs.unlink(filePath, cb);
  } else {
    cb(null);
  }
};

module.exports = function(opts) {
  return new TempDiskAndHashStorage(opts || {});
};
