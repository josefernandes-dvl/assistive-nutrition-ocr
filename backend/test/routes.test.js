const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

const ocrRouter = require('../src/routes/ocr');

function startTestServer() {
  const app = express();
  app.use(express.json());
  app.use('/api/ocr', ocrRouter);
  return new Promise((resolve) => {
    const server = app.listen(0, () => resolve(server));
  });
}

function post(server, path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: server.address().port,
        path,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
      },
      (res) => {
        let buf = '';
        res.on('data', (chunk) => (buf += chunk));
        res.on('end', () => {
          let json;
          try { json = JSON.parse(buf); } catch { json = buf; }
          resolve({ status: res.statusCode, body: json });
        });
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

test('POST /api/ocr/analyze sem ingredientes nem barcode → 400', async () => {
  const server = await startTestServer();
  try {
    const res = await post(server, '/api/ocr/analyze', {
      disorders: ['Doença Celíaca'],
    });
    assert.equal(res.status, 400);
    assert.match(res.body.error, /ingredients|barcode/i);
  } finally {
    server.close();
  }
});

test('POST /api/ocr/analyze com ingredientes válidos → 200 + análise', async () => {
  const server = await startTestServer();
  try {
    const res = await post(server, '/api/ocr/analyze', {
      ingredients: ['Farinha de trigo', 'Açúcar'],
      disorders: ['Doença Celíaca'],
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.summary.total, 2);
    assert.equal(res.body.summary.flagged, 1);
  } finally {
    server.close();
  }
});

test('POST /api/ocr/analyze com disorders inválido → 400', async () => {
  const server = await startTestServer();
  try {
    const res = await post(server, '/api/ocr/analyze', {
      ingredients: ['Açúcar'],
      disorders: 'string-em-vez-de-array',
    });
    assert.equal(res.status, 400);
  } finally {
    server.close();
  }
});
