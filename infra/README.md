# infra — Infraestrutura e deploy

Templates EasyPanel/Docker, `docker-compose` de dev e scripts de deploy.

## Serviços (EasyPanel — staging e produção SEPARADOS desde o dia 1)

| Container | Papel |
|---|---|
| `gogem-db` | PostgreSQL 16 (multi-tenant; `tenant_id` + RLS) |
| `gogem-redis` | Cache de cardápio publicado, filas (BullMQ), sessões |
| `gogem-media` | MinIO (S3) — fotos, logos white-label, pacotes OTA assinados |
| `gogem-api` | API núcleo (REST + WebSocket) |
| `gogem-admin` | Backoffice web (SPA) |
| n8n (existente) | Alertas WhatsApp/e-mail, automações de onboarding |
| Traefik/Nginx | TLS, subdomínios `api.` `admin.` `ota.` |

Regras: backup diário do Postgres → MinIO + cópia externa; segredos no gerenciador do EasyPanel (nunca no repo); logs centralizados.

> **Nota:** o workflow de CI que o GitHub executa vive em `.github/workflows/ci.yml` (o GitHub Actions só lê workflows de lá). Esta pasta guarda os templates de deploy/compose.

> Vazio no S0 além deste guia. `docker-compose.yml` de dev entra junto com a API (S1).
