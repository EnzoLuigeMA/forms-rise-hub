# Forms Rise Hub

Funil de **captação e qualificação de leads + agendamento de consultoria** para clínicas
(médicas, odonto, estética) — mercado BR. Site **estático** (HTML + CSS + JS puro, sem
build/framework) hospedado na **Vercel**, com **Supabase** como banco e **Meta Pixel +
Conversions API (CAPI)** para atribuição de anúncios.

## Stack

- HTML + CSS + JavaScript puro (sem framework, sem build, sem dependências).
- Hospedagem **Vercel** (rewrites + cache + Analytics/Speed Insights) + 1 função serverless (`/api`).
- Banco **Supabase** (PostgREST).
- **Meta Pixel** (client) + **Conversions API** (server, via `/api/meta-capi`).

## Estrutura de arquivos

```
index.html          Formulário principal de qualificação (multi-step)
lp.html             Landing page institucional (com form + agendamento embutidos)
lp-trafego.html     Landing page para tráfego pago (variante)
agendar.html        Tela de agendamento (calendário + horários)
diagnostico.html    Ferramenta interna de diagnóstico do Supabase (não faz parte do funil)
vercel.json         Rewrites de rota + headers de cache/segurança
api/
  meta-capi.js      Função serverless: proxy da Meta Conversions API (esconde o token)
supabase/
  README.md         Runbook do hardening de RLS
  migrations/
    0001_create_rpcs.sql   RPCs seguras (lead_exists, get_available_slots, mark_lead_scheduled, update_lead_qualification)
    0002_enable_rls.sql    Ativa RLS e remove o acesso direto do anon
.env.example        Variáveis exigidas pela função serverless (configurar na Vercel)
```

## Rotas (Vercel rewrites)

| Rota | Arquivo |
|---|---|
| `/bio`, `/form` | `index.html` |
| `/lp` | `lp.html` |
| `/trafego` | `lp-trafego.html` |
| `/agendar` | `agendar.html` |

## Banco de dados (Supabase — projeto `ibidukamkkgsurqswsvf`)

- **`leads_rise_hub`** — leads do funil (contato, qualificação, lead score, atribuição UTM/fbclid).
- **`bookings_rise_hub`** — agendamentos (data/hora, plataforma, duração, status).

### Segurança / acesso (importante)

O `anon` (chave pública embutida no client) pode **apenas INSERIR**. Leitura e atualização
acontecem por **RPCs `SECURITY DEFINER`** que devolvem só o necessário:

| RPC | Para quê |
|---|---|
| `lead_exists(p_email, p_whatsapp)` | checar lead duplicado (devolve boolean) |
| `get_available_slots(p_from, p_to)` | horários ocupados (sem PII) |
| `mark_lead_scheduled(p_notas, p_lead_id, p_email)` | marcar lead como `agendado` |
| `update_lead_qualification(p_lead_id, …)` | profiling progressivo (LP) |

> Detalhes e ordem de aplicação das migrations: **`supabase/README.md`**.
> O `service_role` (CRM/dashboard/backend) ignora RLS e mantém acesso total.

## Fluxo de dados

```
Formulário → lead_exists (dedupe) → INSERT lead → Pixel + /api/meta-capi (CAPI) → obrigado
  → /agendar → get_available_slots → INSERT booking → mark_lead_scheduled → confirmação
```

## Lead scoring

Algoritmo por pontos (volume de atendimentos, automação, dor principal, orçamento, interesses,
cargo, gasto em ads, tamanho da equipe) → classifica em **HOT / WARM / COLD**. Os limiares
variam por página (ex.: `index.html` usa HOT ≥ 140 / WARM ≥ 80).

## Variáveis de ambiente

Configuradas na **Vercel** (projeto `forms-rise-hub` → Settings → Environment Variables),
usadas pela função `/api/meta-capi`:

| Var | Descrição |
|---|---|
| `META_PIXEL_ID` | ID do pixel/dataset (`2238173290034845`) |
| `META_ACCESS_TOKEN` | token da Conversions API (**nunca** no client) |

`SUPABASE_URL` e `SUPABASE_ANON_KEY` ficam no client (são públicas; a proteção vem do RLS).
Ver `.env.example`.

## Deploy

Deploy automático pela integração Git da Vercel. Para que o CAPI funcione, garanta as env
vars acima. Para o hardening do banco, siga o runbook em `supabase/README.md` (aplicar
`0001` → deploy → aplicar `0002`).

## Notas

- `diagnostico.html` testa acesso **direto** às tabelas; após o hardening (RLS), os testes de
  SELECT/PATCH/DELETE dessa página **passam a falhar de propósito** (o anon não tem mais esse
  acesso). É uma ferramenta interna, fora do funil.
- O token da Meta que estava exposto no client foi removido; **rotacione-o** no Events Manager,
  pois o valor antigo já vazou (client + histórico do git).
