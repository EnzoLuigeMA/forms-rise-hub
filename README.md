# Rise Hub — Forms & Landing Pages

Front-end de **captação e qualificação de leads** (topo de funil) do **Rise Hub**, uma solução de
IA/automação para clínicas (médicas, odontológicas, de estética, psicologia/psiquiatria). São
páginas **estáticas** que qualificam o lead, calculam um *score*, gravam no banco e agendam uma
reunião.

> ℹ️ Este repositório é **apenas o topo de funil** (aquisição). O produto SaaS em si (gestão de
> clínicas) vive em outra base — veja a seção *Ecossistema*.

## Stack

| Item | Detalhe |
|---|---|
| Linguagem | HTML + **JavaScript puro (vanilla)**, CSS inline |
| Build / dependências | **Nenhum** — sem `package.json`, sem TypeScript, sem framework, sem bundler |
| Hospedagem | **Vercel** (estático + Speed Insights + Web Analytics) |
| Dados | **Supabase** (REST direto do navegador) |
| Tracking | **Meta Pixel** + **Conversions API (CAPI)** |

Não há etapa de build: os arquivos `.html` são servidos como estão.

## Páginas & rotas

As rotas "limpas" são definidas em `vercel.json` (rewrites):

| Arquivo | Rota(s) | Função |
|---|---|---|
| `index.html` | `/`, `/bio`, `/form` | Formulário de qualificação em 4 etapas → redireciona para `/agendar` |
| `lp.html` | `/lp` | Landing page principal + funil "IA" (hero, features, prova social, FAQ) |
| `lp-trafego.html` | `/trafego` | Funil especializado em tráfego pago / gestão de anúncios |
| `agendar.html` | `/agendar` | Agendamento de reunião (seg–sex, slots de 90 min, Google Meet) |
| `diagnostico.html` | — | Ferramenta de teste de conexão/escrita no Supabase |
| `vercel.json` | — | Rewrites de rota, cache (`s-maxage`) e headers de segurança |

### Fluxo do lead
1. Usuário entra por `/`, `/bio`, `/lp` ou `/trafego`.
2. Preenche o formulário multi-etapas (segmento → contato → operação → interesse/orçamento).
3. O lead é validado, recebe um **score** (HOT/WARM/COLD) e é gravado no Supabase (`leads_rise_hub`).
4. Eventos são enviados ao **Meta Pixel** e à **Conversions API**.
5. Redireciona para `/agendar`, que lê horários ocupados e grava o agendamento (`bookings_rise_hub`).

## Integrações

- **Supabase** — tabelas `leads_rise_hub` e `bookings_rise_hub`, via REST (`/rest/v1/...`). Dedupe de
  lead por e-mail/WhatsApp + `localStorage`/cookie.
- **Meta Pixel + Conversions API** — eventos de funil (PageView → ViewContent → InitiateCheckout →
  AddToCart → AddPaymentInfo → **Lead**); PII enviada com hash SHA-256 e deduplicação via `event_id`.
- **Vercel** — hosting, rewrites, cache e analytics.
- **Atribuição** — captura de `utm_*`, `fbclid`, `gclid` e `entry_point`.

> 🔐 As credenciais hoje ficam **inline no HTML**. A *anon key* do Supabase é pública por design
> (protegida por RLS), mas há um **token da Meta CAPI exposto no cliente** que deveria sair do
> front-end. Veja `CLAUDE.md` → *Known issues*.

## Rodando localmente

Como tudo é estático, basta servir a pasta:

```bash
python3 -m http.server 8000
# abra http://localhost:8000/index.html
```

> Atenção: as rotas limpas (`/bio`, `/lp`, etc.), o cache e os headers só existem na Vercel
> (via `vercel.json`). Localmente, acesse os arquivos `.html` diretamente.

## Deploy

Push para a branch publica automaticamente na Vercel. O `vercel.json` controla rewrites, cache e
headers — não há comando de build.

## Ecossistema

As landing pages vendem um produto SaaS de gestão de clínicas (multi-tenant, com IA, prontuário,
agenda, CRM, campanhas e billing) que vive em **outra base de dados** (não neste repositório). Este
repo é a camada de aquisição que alimenta esse produto.
