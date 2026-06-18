# Deploy do Backend — Render + MongoDB Atlas

Custo: **R$ 0,00**. Cold start de ~30s no Render free quando dorme, depois é instantâneo.

---

## Visão geral

```
GitHub (push)
    ↓ (auto-deploy)
Render (Node.js)  ←──── MONGO_URI ────  MongoDB Atlas (free M0, 512MB)
    ↓ (HTTPS público)
APK Android (--dart-define=BACKEND_URL=https://...)
```

---

## 1. MongoDB Atlas (5 min)

1. Acesse https://www.mongodb.com/cloud/atlas/register e crie conta (Google login funciona).
2. **Build a Database** → **M0 FREE** (sem cartão).
3. **Provider**: AWS · **Region**: `us-east-1` (Virginia) — mesma região do Render Oregon não importa muito; latência ~50ms.
4. **Cluster name**: `nutriscan-cluster` (ou o que preferir) → **Create**.
5. **Security Quickstart**:
   - **Username**: `nutriscan` · **Password**: gere uma forte e **anote**.
   - **Where would you like to connect from?**: `0.0.0.0/0` (acesso de qualquer IP — necessário porque o IP do Render é dinâmico). Em produção real, restringiria para os IPs da Render.
6. **Finish and Close**.
7. **Database** → **Connect** → **Drivers** → copie a string `mongodb+srv://nutriscan:<password>@nutriscan-cluster.xxxxx.mongodb.net/?retryWrites=true&w=majority`
8. Substitua `<password>` pela senha real e acrescente o nome do database antes do `?`:
   ```
   mongodb+srv://nutriscan:SUA_SENHA@nutriscan-cluster.xxxxx.mongodb.net/nutriscan?retryWrites=true&w=majority
   ```
9. Guarde essa URL — é o `MONGO_URI` que vai no Render.

---

## 2. Push do código pro GitHub (se ainda não estiver)

```bash
cd "/home/jose/Área de trabalho/Projeto IC/assistive-nutrition-ocr"
git add -A
git commit -m "feat: deploy infra (render.yaml + Dockerfile + docs)"
git push origin main
```

O `render.yaml` já está versionado na raiz.

---

## 3. Render (3 min)

1. Acesse https://dashboard.render.com/register e crie conta (GitHub login facilita).
2. **New** → **Blueprint**.
3. **Connect GitHub** → autorize → selecione o repo `assistive-nutrition-ocr`.
4. Render lê o `render.yaml` da raiz e mostra "Found 1 service: nutriscan-backend".
5. **Apply** → começa o deploy (~3-5 min na primeira vez).
6. Enquanto builda, **adicione a env var do Mongo**:
   - Acesse o serviço → **Environment** → **Add Environment Variable**
   - **Key**: `MONGO_URI` · **Value**: a URL completa do Atlas (passo 1.8)
   - **Save Changes** → Render reinicia o serviço com a nova env var

Quando terminar, aparece a URL pública no topo:
```
https://nutriscan-backend.onrender.com
```

(o subdomínio exato pode variar — pegue o que apareceu).

---

## 4. Validar o deploy

Do seu terminal (ou de qualquer lugar):

```bash
# Health
curl -s https://nutriscan-backend.onrender.com/api/health | jq

# Análise sem barcode
curl -s -X POST https://nutriscan-backend.onrender.com/api/ocr/analyze \
  -H "Content-Type: application/json" \
  -d '{"ingredients":["Farinha de trigo","Leite em pó"],"disorders":["Doença Celíaca"]}' | jq

# Análise por código de barras (Trakinas)
curl -s -X POST https://nutriscan-backend.onrender.com/api/ocr/analyze \
  -H "Content-Type: application/json" \
  -d '{"barcode":"7622210449283","disorders":["Doença Celíaca","Intolerância à Lactose"]}' | jq '.product.name, .official_allergens'
```

Se o Mongo estiver conectado:
```bash
curl -s https://nutriscan-backend.onrender.com/api/health | jq .mongodb
# Esperado: "connected"
```

---

## 5. Rebuilda o APK apontando para o backend público

```bash
cd "/home/jose/Área de trabalho/Projeto IC/assistive-nutrition-ocr/mobile"
flutter build apk --release \
  --target-platform android-arm64 \
  --dart-define=BACKEND_URL=https://nutriscan-backend.onrender.com/api
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Agora o celular acessa o backend pela internet — **funciona em qualquer rede** (LAN, 4G, WiFi diferente), sem precisar de firewall liberado nem mesma rede do PC.

---

## 6. Atualizações futuras

```bash
git push origin main
```

Pronto. Render detecta o push, builda, faz health check, faz swap atômico (zero downtime).

---

## 7. Cold start no free tier

O free tier do Render **adormece após 15min sem requests**. A primeira chamada depois disso leva ~30s para acordar.

Soluções (se virar problema):
1. **Não fazer nada** — para testes esporádicos do IC, é aceitável.
2. **Cron warming**: serviço externo (UptimeRobot grátis) que faz ping em `/api/health` a cada 10min. Mantém vivo, mas conta nas 750h/mês free do Render — pode estourar.
3. **Upgrade para Starter** ($7/mês) — sem sleep.

Recomendo a #1 para o IC. Quando partir para usuários reais, considere #3.

---

## 8. Troubleshooting

| Sintoma | Causa | Fix |
|---|---|---|
| Build falha com "command not found" | Render rodando wrong build cmd | Confira `render.yaml` está na raiz do repo |
| `/api/health` retorna `mongodb: disconnected` mas devia estar conectado | `MONGO_URI` faltando ou senha errada | Verifique env var no Render → Environment |
| Atlas rejeita conexão | IP não whitelist | Atlas → Network Access → `0.0.0.0/0` |
| Cold start atrapalhando teste | Free tier dormiu | Faça uma requisição de "warm-up" antes |
| `flutter build apk` reclama da URL | Falta `https://` ou tem `/` no final | Confira a URL — deve ser `https://xxx.onrender.com/api` sem barra no fim |

---

## 9. Quando passar pra HTTPS-only no app

Hoje o `network_security_config.xml` permite tráfego HTTP em cleartext. Quando você só usar a URL HTTPS do Render:

1. Edite [mobile/android/app/src/main/res/xml/network_security_config.xml](../mobile/android/app/src/main/res/xml/network_security_config.xml)
2. Mude `cleartextTraffic="true"` → `"false"`
3. Mais seguro: ataques MitM em redes públicas ficam impossíveis.

Mantenha HTTP enquanto você ainda testa em LAN.
