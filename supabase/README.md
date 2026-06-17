# Supabase — Hardening do projeto "Forms Rise Hub"

Projeto: **Forms Rise Hub** (`ibidukamkkgsurqswsvf`).
Tabelas: `leads_rise_hub` (leads) e `bookings_rise_hub` (agendamentos).

## Por que isso existe

Auditoria detectou que, com a **anon key pública** (embutida no client), qualquer
pessoa conseguia **ler todos os leads e agendamentos** (PII completo: nome, email,
WhatsApp, clínica) e até **apagar/atualizar** registros diretamente via REST API.
Causa: RLS desligado (ou com policy de `SELECT` aberta para `anon`).

A correção mantém o funil funcionando, mas fecha o acesso direto: o `anon` passa a
poder **só inserir**; leitura e atualização acontecem por **RPCs `SECURITY DEFINER`**
que devolvem apenas o necessário (boolean de duplicado, horários sem PII, update de status).

## Ordem de aplicação (importante — evita janela quebrada)

1. **Aplique `migrations/0001_create_rpcs.sql`** no SQL Editor do projeto.
   (Aditivo: cria as 3 RPCs. Não quebra nada.)
2. **Faça deploy do client novo** (este repositório) — `index.html`, `lp.html`,
   `lp-trafego.html`, `agendar.html` já chamam as RPCs.
3. **Aplique `migrations/0002_enable_rls.sql`** — ativa o RLS e remove o acesso
   direto do `anon`. A partir daqui o vazamento está fechado.

> Se inverter a ordem (RLS antes do client novo), a tela de agendamento e o
> update de status do lead param de funcionar até o deploy do client.

## RPCs criadas

| RPC | Uso no client | Retorno |
|---|---|---|
| `lead_exists(p_email, p_whatsapp)` | checagem de lead duplicado | `boolean` |
| `get_available_slots(p_from, p_to)` | horários ocupados na tela de agendamento | linhas `(booking_date, duration_minutes)` |
| `mark_lead_scheduled(p_notas, p_lead_id, p_email)` | marca lead como `agendado` | `integer` (linhas afetadas) |
| `update_lead_qualification(p_lead_id, …)` | profiling progressivo da LP (campos de qualificação) | `integer` (linhas afetadas) |

> Os INSERTs de lead que precisavam do `id` de volta (`lp.html`, `lp-trafego.html`) passaram a
> **gerar o UUID no client** (`crypto.randomUUID()`) e usar `Prefer: return=minimal` — assim não
> dependem de `SELECT`/`return=representation`, que o RLS bloqueia.

## Como verificar depois

- No SQL Editor: as queries de verificação no fim de `0002_enable_rls.sql`.
- Com a anon key, um `GET /rest/v1/leads_rise_hub?select=id&limit=1` deve voltar
  **vazio / erro de permissão** (não mais dados).
- Funil end-to-end: preencher o form (insere lead + checa duplicado via RPC) e
  agendar (lê horários via RPC + marca status via RPC).

## Riscos residuais (menores, documentados)

- `lead_exists` é um "oráculo de existência" (dá pra testar se um email/telefone
  está cadastrado). Necessário para a UX de deduplicação; aceitável.
- `anon` ainda pode **inserir** leads/bookings (possível spam). Pré-existente; se
  virar problema, dá pra adicionar rate-limit/captcha ou validações no `with check`.
- `mark_lead_scheduled` permite marcar qualquer lead como agendado — mas é bem mais
  restrito que o PATCH aberto de antes (só `status` + `notas_internas`).
