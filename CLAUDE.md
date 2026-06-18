# CLAUDE.md — contexto para agentes

## O que é
Funil estático (HTML + CSS + **JS puro, sem build/framework**) de captação de leads para
clínicas, na Vercel. Banco Supabase + Meta Pixel/CAPI. Tudo em pt-BR.

## Arquivos-chave
- `index.html` — form principal. `lp.html` / `lp-trafego.html` — landing pages (form + agendamento embutidos). `agendar.html` — agendamento. `diagnostico.html` — ferramenta interna (fora do funil).
- `api/meta-capi.js` — função serverless (proxy CAPI; lê `META_PIXEL_ID`/`META_ACCESS_TOKEN` da env da Vercel).
- `supabase/migrations/` — SQL de RLS + RPCs. `vercel.json` — rotas/cache.

## Convenções / cuidados
- **Sem build**: editar HTML direto; o JS fica embutido em `<script>`. Não há `package.json`.
- **Nunca** colocar segredos no client (token da Meta etc.). O CAPI vai por `/api/meta-capi`.
- Acesso ao banco pelo client (`anon`) é **só INSERT**. Leitura/update via RPCs:
  `lead_exists`, `get_available_slots`, `mark_lead_scheduled`, `update_lead_qualification`.
  Se precisar de novo acesso a dados, criar/expandir RPC `SECURITY DEFINER` — não abrir SELECT pro anon.
- INSERT de lead que precisa do `id` depois usa **`crypto.randomUUID()` no client** + `return=minimal`
  (não usar `return=representation`, que o RLS bloqueia).

## Integrações (verificado via MCP)
- **Supabase**: projeto "Forms Rise Hub" (`ibidukamkkgsurqswsvf`, org `tektxtgkwopdejltvdyd`).
  O MCP padrão da sessão pode estar em outra org; o `SUPABASE_ACCESS_TOKEN` do ambiente alcança este projeto
  (mas sem permissão de query/DDL — aplicar SQL pelo dashboard).
- **Meta**: pixel/dataset `2238173290034845` ("Rise Hub"), business `103922845055886` (RISE HUB - Matriz).
- **Vercel**: projeto `forms-rise-hub` (team `team_ATen7LmrwWjNqicFZar3r0b3`).
