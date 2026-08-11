# Totem GoGeM no Windows (F13)

Roda o mesmo app do totem (Flutter) num **PC Windows** em vez do Android/Tinker.
Pagamento (MP Point + PIX) é backend — **igual** ao Android, sem mudança. A
**comanda do cliente** imprime na **mesma Epson TM-T88** do ponto de teste,
instalada como impressora do Windows, via `winspool` (RAW).

> ⚠️ Diferença vs. Android: no Windows a impressão passa pela **fila do Windows
> (só escrita)**. Não há o canal de status fino do Epson (near-end). O status é
> **grosso** (sem papel / offline / tampa / erro), lido do spooler — suficiente
> para o portão (o totem não vende com a impressora sem papel/offline).

## 0. Pré-requisitos (uma vez, na máquina de build)

1. **Flutter** instalado (canal stable) e no PATH.
2. **Visual Studio Build Tools** com o workload **"Desenvolvimento para desktop com C++"**.
   - Baixe: https://visualstudio.microsoft.com/pt-br/downloads/ → "Ferramentas de Build para Visual Studio".
   - No instalador, marque **Desktop development with C++**.
3. **Developer Mode LIGADO** (o build de plugins usa symlinks):
   - Abra: `Configurações → Privacidade e segurança → Para desenvolvedores` (ou rode `start ms-settings:developers`).
   - Ligue **Modo de desenvolvedor**.
   - Verifique: `flutter doctor` deve mostrar `[√] Visual Studio` e `[√] Develop for Windows`.

## 1. Gerar o scaffold Windows (uma vez, por checkout)

Os platform folders **não são versionados** (convenção do repo — como o Android).
No diretório `apps/kiosk`:

```
flutter create --platforms=windows --project-name gogem_kiosk .
flutter pub get
```

Isso cria `apps/kiosk/windows/` já com os plugins registrados (window_manager,
sqlite3, etc.). Não precisa editar nada nativo — tudo é Dart.

## 2. Instalar a impressora no Windows

1. Conecte a **Epson TM-T88** por USB.
2. Instale o driver:
   - **Recomendado:** driver oficial Epson (Advanced Printer Driver / APD) — melhor status no spooler; **ou**
   - **Genérico:** `Generic / Text Only` (funciona pro RAW ESC/POS, status mais pobre).
3. Anote o **NOME EXATO** da impressora: `Configurações → Bluetooth e dispositivos → Impressoras e scanners` (ex.: `EPSON TM-T88V Receipt`).
   - Esse nome vai em `GOGEM_PRINTER_NAME` (passo 3). Tem que ser **idêntico**.

## 3. Buildar o app

No diretório `apps/kiosk` (troque o nome da impressora pelo do passo 2):

```
flutter build windows --release ^
  --dart-define=GOGEM_API_URL=https://api.gogem.com.br/api/v1 ^
  --dart-define=GOGEM_PAYMENT_PROVIDER=mppoint ^
  --dart-define=GOGEM_PRINTER=winspool ^
  --dart-define=GOGEM_PRINTER_NAME="EPSON TM-T88V Receipt"
```

- Saída: `apps/kiosk/build/windows/x64/runner/Release/` (pasta com `gogem_kiosk.exe` + DLLs).
- **Distribua a pasta Release inteira** (o `.exe` sozinho não roda — precisa das DLLs ao lado).
- `--dart-define=GOGEM_KIOSK_LOCK=false` desliga a trava de fechar a janela (útil para **testar**; em produção deixe ligado, que é o default).

Validar o build: rode o `.exe`, faça um pedido de teste e confirme que a comanda
saiu na Epson e o pedido caiu no KDS.

## 4. Trava de quiosque

**Nível do app (já no código):** janela em **tela cheia** e, com a trava ligada
(default), **Alt+F4 não fecha**.

**Nível do SO (configuração, escolha uma):**
- **Simples — auto-início travado:** coloque o `.exe` no **Inicializar** (`shell:startup`)
  e use uma conta local dedicada sem outras permissões. O usuário liga o PC e cai
  direto no totem.
- **Completo — Shell Launcher** (Windows **Enterprise/Education**): substitui o
  `explorer.exe` pelo `gogem_kiosk.exe` para a conta do totem (sem desktop/menu).
  Guia: `Assigned Access / Shell Launcher` da Microsoft.
  - ⚠️ O assistente "Quiosque" das Configurações (Assigned Access clássico) só
    aceita apps **UWP** — não serve para o `.exe` Win32. Use **Shell Launcher**.

## 5. Atualizar

Rebuild (passo 3) e substitua a pasta `Release` na máquina do totem. (O
auto-update OTA do APK é do Android; no Windows a atualização é manual por ora.)

## Solução de problemas

| Sintoma | Causa provável |
|---|---|
| "impressora do Windows não configurada" | `GOGEM_PRINTER_NAME` vazio no build. |
| "fila \"X\" indisponível" | Nome ≠ do Windows, ou impressora offline/desconectada. |
| Totem bloqueia a venda: "sem papel/offline" | Status real do spooler — reponha papel / religue a impressora. |
| Build para em "requires symlink support" | **Developer Mode** desligado (passo 0.3). |
| `.exe` não abre em outra máquina | Faltam as DLLs — distribua a pasta `Release` inteira. |
