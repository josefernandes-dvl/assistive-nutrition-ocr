const express = require("express");
const mongoose = require("mongoose");

const scansRouter = require("./routes/scans");
const profilesRouter = require("./routes/profiles");
const ocrRouter = require("./routes/ocr");
const productsRouter = require("./routes/products");

const app = express();
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27017/nutriscan";

// Falha explícita se a porta estiver ocupada (em vez de exit 0 silencioso)
process.on("uncaughtException", (err) => {
  if (err && err.code === "EADDRINUSE") {
    console.error(`\nFATAL: porta ${PORT} já está em uso por outro processo.`);
    console.error("Libere a porta ou defina PORT=3001 (ex.: PORT=3001 npm start).");
    process.exit(1);
  }
  console.error("Uncaught exception:", err);
  process.exit(1);
});

// Middleware
app.use(express.json({ limit: "10mb" }));

// CORS (permite o app Flutter conectar)
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Content-Type, Accept");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

// Rotas
app.get("/", (req, res) => {
  res.json({ message: "API NutriScan - Assistive Nutrition OCR", status: "online" });
});

app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    mongodb: mongoose.connection.readyState === 1 ? "connected" : "disconnected",
    timestamp: new Date().toISOString(),
  });
});

app.use("/api/scans", scansRouter);
app.use("/api/profiles", profilesRouter);
app.use("/api/ocr", ocrRouter);
app.use("/api/products", productsRouter);

// Sobe o servidor independentemente do MongoDB — as rotas que precisam de
// persistência (scans/profiles) reportarão erro, mas /api/ocr e /api/products
// continuam funcionando para análise online.
app.listen(PORT, () => {
  const isProd = process.env.NODE_ENV === "production";
  console.log(`[NutriScan] Servidor escutando na porta ${PORT} (env: ${isProd ? "production" : "development"})`);
  if (!isProd) {
    console.log(`[NutriScan] Health check: http://localhost:${PORT}/api/health`);
  }
});

// Listener silencioso para erros futuros do driver (evita crash)
mongoose.connection.on("error", (err) => {
  console.warn("MongoDB (erro pós-conexão):", err.message);
});

mongoose
  .connect(MONGO_URI, { serverSelectionTimeoutMS: 4000 })
  .then(() => {
    console.log("MongoDB conectado em:", MONGO_URI);
  })
  .catch((err) => {
    console.warn("Aviso: MongoDB não conectado —", err.message);
    console.warn("As rotas /api/ocr e /api/products CONTINUAM funcionando normalmente.");
    console.warn("MongoDB é opcional: só é necessário para histórico (/api/scans) e perfil (/api/profiles).");
    console.warn("Para habilitar (caminho mais fácil — Docker):");
    console.warn("  docker run -d --name nutriscan-mongo -p 27017:27017 mongo:7");
  });

// Garante que erros não tratados não derrubem o servidor durante desenvolvimento
process.on("unhandledRejection", (reason) => {
  console.warn("Unhandled rejection:", reason && reason.message ? reason.message : reason);
});
