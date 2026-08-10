/**
 * CA12 — um código EAN-13 presente na base externa retorna nome, marca e
 *        alérgenos oficiais em até 5 s com o servidor ativo (RF22, RF26).
 *
 * A medição usa um stub local da Open Food Facts. Isso é proposital: medir
 * contra a OFF real tornaria o critério dependente da rede do avaliador e da
 * disponibilidade de um serviço de terceiros, e o que o critério verifica é o
 * comportamento do NutriScan — inclusive o orçamento de tempo que ele impõe à
 * consulta externa. Há um teste contra a OFF real, desligado por padrão, ao
 * final do arquivo (RUN_LIVE_OFF=1).
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

const EAN = '7622210449283';

/** Resposta enxuta no formato da API v2 da Open Food Facts. */
const PRODUTO_OFF = {
  status: 1,
  product: {
    code: EAN,
    product_name_pt: 'Biscoito Recheado Chocolate',
    brands: 'Marca Teste',
    image_url: 'https://exemplo.invalid/front.jpg',
    ingredients_text_pt:
      'Farinha de trigo enriquecida, açúcar, gordura vegetal, soro de leite',
    ingredients: [
      { text: 'Farinha de trigo enriquecida' },
      { text: 'Açúcar' },
      { text: 'Soro de leite' },
    ],
    allergens_tags: ['en:gluten', 'en:milk', 'en:soybeans'],
    traces_tags: ['en:peanuts'],
    nova_group: 4,
    nutriscore_grade: 'd',
    nutriments: {
      'energy-kcal_100g': 489,
      fat_100g: 21,
      'saturated-fat_100g': 10,
      carbohydrates_100g: 66,
      sugars_100g: 33,
      fiber_100g: 2.4,
      proteins_100g: 5.6,
      sodium_100g: 0.35,
    },
  },
};

/** Sobe um stub da OFF; `atraso` simula latência do serviço externo. */
function startOffStub({ atraso = 0, status = 200, payload = PRODUTO_OFF } = {}) {
  const estado = { chamadas: 0 };
  const app = express();
  app.get('/api/v2/product/:code.json', (req, res) => {
    estado.chamadas++;
    setTimeout(() => {
      if (status !== 200) return res.status(status).json({ error: 'stub' });
      const code = req.params.code.replace(/\.json$/, '');
      if (code !== EAN) return res.json({ status: 0 });
      res.json(payload);
    }, atraso);
  });

  return new Promise((resolve) => {
    const server = app.listen(0, () => {
      process.env.OFF_BASE_URL = `http://127.0.0.1:${server.address().port}`;
      resolve({ server, estado });
    });
  });
}

/** Sobe a API do NutriScan com as rotas que o fluxo de barcode usa. */
function startApi() {
  const app = express();
  app.use(express.json());
  app.use('/api/products', require('../src/routes/products'));
  app.use('/api/ocr', require('../src/routes/ocr'));
  return new Promise((resolve) => {
    const server = app.listen(0, () => resolve(server));
  });
}

function request(server, { path, method = 'GET', body = null }) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const inicio = process.hrtime.bigint();
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: server.address().port,
        path,
        method,
        headers: data
          ? {
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(data),
            }
          : {},
      },
      (res) => {
        let buf = '';
        res.on('data', (c) => (buf += c));
        res.on('end', () => {
          let json;
          try {
            json = JSON.parse(buf);
          } catch {
            json = buf;
          }
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: json,
            elapsedMs: Number(process.hrtime.bigint() - inicio) / 1e6,
          });
        });
      }
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

/** Cada teste começa com cache limpo e stub próprio. */
async function comAmbiente(opcoes, fn) {
  const { clearCache } = require('../src/services/openFoodFacts');
  clearCache();
  const { server: off, estado } = await startOffStub(opcoes);
  const api = await startApi();
  try {
    return await fn({ api, estado });
  } finally {
    api.close();
    off.close();
    delete process.env.OFF_BASE_URL;
  }
}

test('CA12 — EAN-13 conhecido retorna nome, marca e alérgenos em menos de 5 s',
  async () => {
    await comAmbiente({ atraso: 120 }, async ({ api }) => {
      const res = await request(api, { path: `/api/products/barcode/${EAN}` });

      assert.equal(res.status, 200);
      assert.equal(res.body.name, 'Biscoito Recheado Chocolate');
      assert.equal(res.body.brand, 'Marca Teste');
      assert.deepEqual(res.body.allergens_tags, [
        'en:gluten',
        'en:milk',
        'en:soybeans',
      ]);
      assert.equal(res.body.nutriscore_grade, 'd');
      assert.equal(res.body.nova_group, 4);

      console.log(
        `CA12 · GET /api/products/barcode: ${res.elapsedMs.toFixed(0)} ms ` +
          `(servidor: ${res.headers['x-response-time-ms']} ms)`
      );
      assert.ok(
        res.elapsedMs < 5000,
        `latência ${res.elapsedMs.toFixed(0)} ms acima de 5000 ms`
      );
    });
  });

test('CA12 — o fluxo completo do leitor (analyze com barcode) cabe em 5 s',
  async () => {
    await comAmbiente({ atraso: 120 }, async ({ api }) => {
      const res = await request(api, {
        path: '/api/ocr/analyze',
        method: 'POST',
        body: {
          ingredients: [],
          barcode: EAN,
          disorders: ['Doença Celíaca', 'Intolerância à Lactose'],
        },
      });

      assert.equal(res.status, 200);
      // Sem ingredientes do OCR, a lista da OFF entra como fallback (RN08).
      assert.equal(res.body.summary.total, 3);
      assert.ok(res.body.summary.flagged >= 2);
      // Alérgenos oficiais correlacionados com o perfil (RF26).
      const tags = res.body.official_allergens.map((a) => a.tag).sort();
      assert.deepEqual(tags, ['en:gluten', 'en:milk']);
      assert.equal(res.body.product.name, 'Biscoito Recheado Chocolate');

      console.log(
        `CA12 · POST /api/ocr/analyze (barcode): ${res.elapsedMs.toFixed(0)} ms`
      );
      assert.ok(res.elapsedMs < 5000);
    });
  });

test('a segunda consulta ao mesmo código não vai à rede (cache)', async () => {
  await comAmbiente({ atraso: 200 }, async ({ api, estado }) => {
    const primeira = await request(api, { path: `/api/products/barcode/${EAN}` });
    const segunda = await request(api, { path: `/api/products/barcode/${EAN}` });

    assert.equal(primeira.status, 200);
    assert.equal(segunda.status, 200);
    assert.equal(estado.chamadas, 1, 'a segunda deveria vir do cache');
    assert.ok(segunda.elapsedMs < primeira.elapsedMs);
  });
});

test('código ausente na base retorna 404 explícito', async () => {
  await comAmbiente({}, async ({ api }) => {
    const res = await request(api, { path: '/api/products/barcode/0000000000000' });
    assert.equal(res.status, 404);
    assert.match(res.body.error, /não encontrado/i);
  });
});

test('serviço externo lento estoura o orçamento e responde 504 dentro de 5 s',
  async () => {
    process.env.OFF_PRODUCT_TIMEOUT_MS = '300';
    delete require.cache[require.resolve('../src/services/openFoodFacts')];
    delete require.cache[require.resolve('../src/routes/products')];
    delete require.cache[require.resolve('../src/routes/ocr')];

    try {
      await comAmbiente({ atraso: 3000 }, async ({ api }) => {
        const res = await request(api, { path: `/api/products/barcode/${EAN}` });
        assert.equal(res.status, 504);
        assert.ok(
          res.elapsedMs < 5000,
          `demorou ${res.elapsedMs.toFixed(0)} ms — o timeout não segurou`
        );
      });
    } finally {
      delete process.env.OFF_PRODUCT_TIMEOUT_MS;
      delete require.cache[require.resolve('../src/services/openFoodFacts')];
      delete require.cache[require.resolve('../src/routes/products')];
      delete require.cache[require.resolve('../src/routes/ocr')];
    }
  });

test('RNF18 — base externa fora do ar não impede a análise dos ingredientes',
  async () => {
    await comAmbiente({ status: 503 }, async ({ api }) => {
      const res = await request(api, {
        path: '/api/ocr/analyze',
        method: 'POST',
        body: {
          ingredients: ['Farinha de trigo', 'Açúcar'],
          barcode: EAN,
          disorders: ['Doença Celíaca'],
        },
      });

      assert.equal(res.status, 200);
      assert.equal(res.body.product, null);
      assert.equal(res.body.summary.flagged, 1);
      assert.deepEqual(res.body.official_allergens, []);
    });
  });

// Consulta à Open Food Facts real. Desligada por padrão para não tornar a
// suíte dependente de rede: rode com RUN_LIVE_OFF=1 para conferir o contrato
// da API externa (D1) e a latência real.
test('CA12 (opcional) — consulta real à Open Food Facts', async (t) => {
  if (process.env.RUN_LIVE_OFF !== '1') {
    t.skip('defina RUN_LIVE_OFF=1 para consultar a Open Food Facts real');
    return;
  }

  const { clearCache } = require('../src/services/openFoodFacts');
  clearCache();
  delete process.env.OFF_BASE_URL;

  const api = await startApi();
  try {
    const res = await request(api, { path: '/api/products/barcode/7891000100103' });
    console.log(
      `CA12 (real) · status ${res.status} · ${res.elapsedMs.toFixed(0)} ms · ` +
        `nome: ${res.body && res.body.name}`
    );
    assert.equal(res.status, 200);
    assert.ok(res.body.name);
    assert.ok(res.elapsedMs < 5000);
  } finally {
    api.close();
  }
});
