/**
 * RA-12 — Rate limiting para endpoints públicos.
 *
 * Os endpoints públicos e caros (/api/ocr e /api/products) não tinham limite de
 * requisições, ficando expostos a abuso e a picos de custo (a base externa Open
 * Food Facts e o processamento de OCR são operações pesadas). Este middleware
 * impõe um limite por IP usando uma janela fixa (fixed-window) em memória.
 *
 * Sem dependências externas: apenas JavaScript puro + um Map, alinhado à
 * restrição de simplicidade do projeto. O estado é por processo (in-memory) —
 * suficiente para uma única instância no Render; se um dia houver múltiplas
 * instâncias, migra-se para um store compartilhado.
 */

// Intervalo de limpeza das entradas expiradas para o Map não crescer sem limite.
const CLEANUP_INTERVAL_MS = 5 * 60 * 1000; // 5 min

/**
 * Fábrica que devolve um middleware Express de rate limit por IP.
 *
 * @param {Object}  opts
 * @param {number}  opts.maxRequests - máximo de requisições permitidas na janela.
 * @param {number}  opts.windowMs    - tamanho da janela, em milissegundos.
 * @returns {import('express').RequestHandler}
 */
function rateLimit({ maxRequests, windowMs }) {
  // Bypass explícito para testes/ambientes controlados (RATE_LIMIT_DISABLED=1).
  // Mantém a suíte de testes livre do limitador de forma limpa e testável.
  const disabled = () => process.env.RATE_LIMIT_DISABLED === '1';

  // chave: IP do cliente -> { count, resetAt }
  const buckets = new Map();

  // Limpeza periódica de janelas já expiradas (RA-12: evita vazamento de memória).
  // unref() garante que o timer não segure o event loop / não impeça o processo
  // (e os testes com node --test) de encerrar.
  const cleanup = setInterval(() => {
    const now = Date.now();
    for (const [ip, entry] of buckets) {
      if (entry.resetAt <= now) buckets.delete(ip);
    }
  }, CLEANUP_INTERVAL_MS);
  if (typeof cleanup.unref === 'function') cleanup.unref();

  return function rateLimitMiddleware(req, res, next) {
    if (disabled()) return next();

    // req.ip depende de app.set('trust proxy', 1) atrás do proxy do Render.
    const ip = req.ip || req.socket?.remoteAddress || 'unknown';
    const now = Date.now();

    let entry = buckets.get(ip);
    if (!entry || entry.resetAt <= now) {
      // Nova janela fixa para este IP.
      entry = { count: 0, resetAt: now + windowMs };
      buckets.set(ip, entry);
    }

    entry.count += 1;

    if (entry.count > maxRequests) {
      const retryAfterSec = Math.max(1, Math.ceil((entry.resetAt - now) / 1000));
      res.set('Retry-After', String(retryAfterSec));
      return res.status(429).json({
        error: 'Muitas requisições. Tente novamente em instantes.',
      });
    }

    next();
  };
}

module.exports = rateLimit;
