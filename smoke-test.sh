#!/usr/bin/env bash
# Smoke test do staging GoGeM — uso: bash smoke-test.sh https://api-stg.gogem.com.br
set -euo pipefail
BASE="${1:?informe a URL base}/api/v1"
EMAIL="smoke+$(date +%s)@dms.dev"; SENHA="Smoke#$(date +%s)"
say(){ printf "\n\033[1;33m▶ %s\033[0m\n" "$*"; }
ok(){ printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
req(){ # req METHOD PATH [JSON] [AUTH]
  local m=$1 p=$2 body=${3:-} auth=${4:-}
  local args=(-sS -w "\n%{http_code}" -X "$m" "$BASE$p" -H "Content-Type: application/json")
  [ -n "$auth" ] && args+=(-H "Authorization: Bearer $auth")
  [ -n "$body" ] && args+=(-d "$body")
  local out; out=$(curl "${args[@]}")
  CODE=$(echo "$out" | tail -1); BODY=$(echo "$out" | sed '$d')
  if [ "$CODE" -ge 300 ]; then echo "FALHOU ($CODE) $m $p"; echo "$BODY"; exit 1; fi
}
say "1/8 health";        req GET /health;            ok "health $CODE"
say "2/8 health/db";     req GET /health/db;         ok "db $CODE"
say "3/8 register";      req POST /auth/register "{\"empresa\":\"Smoke Lanches\",\"nome\":\"Smoke\",\"email\":\"$EMAIL\",\"senha\":\"$SENHA\"}"
TOKEN=$(echo "$BODY" | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])"); ok "tenant criado"
say "4/8 auth/me";       req GET /auth/me "" "$TOKEN"; ok "me $CODE"
say "5/8 import regem";  req POST /import/regem "{}" "$TOKEN"; echo "$BODY" | head -c 400; echo; ok "import $CODE"
say "6/8 produtos";      req GET "/produtos" "" "$TOKEN"
COUNT=$(echo "$BODY" | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d if isinstance(d,list) else d.get('items',d)))")
ok "produtos no catálogo: $COUNT"
say "7/8 publicar";      req POST /catalogo/publicar "{}" "$TOKEN"
VER=$(echo "$BODY" | python3 -c "import sys,json;print(json.load(sys.stdin).get('versao','?'))"); ok "versão publicada: $VER"
say "8/8 publicado";     req GET "/catalogo/publicado" "" "$TOKEN"
echo "$BODY" | python3 -c "import sys,json;d=json.load(sys.stdin);print('snapshot ok, chaves:',list(d)[:6])"
ok "SMOKE TEST COMPLETO ✅"
