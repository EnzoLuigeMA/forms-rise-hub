# CLAUDE.md

Guia operacional para agentes de IA trabalhando neste repositório.

## Visão geral

`forms-rise-hub` é o **front-end de captação/qualificação de leads (topo de funil)** do produto
**Rise Hub** (IA/automação para clínicas). São páginas **estáticas** (HTML + JS puro) hospedadas na
**Vercel**, que qualificam o lead, calculam um *score*, gravam no **Supabase** e disparam eventos
para o **Meta Pixel/CAPI**.

⚠️ **Este repo NÃO é o produto.** É só a máquina de aquisição. O SaaS de gestão de clínicas vive em
outra base (ver *Ecossistema relacionado*).

## Como o repositório é mantido

- **Não há build, `package.json`, lockfile, TypeScript ou framework.** Não rode `npm install`/build.
- O histórico Git é majoritariamente "Add files via upload"/"Delete" → o repo costuma ser editado
  pela **UI web do GitHub / export estilo Lovable**, não por dev local.
- Para alterar algo, **edite o HTML diretamente** (o JS e o CSS ficam inline no mesmo arquivo).
- Deploy: push para a branch → a Vercel publica os estáticos. `vercel.json` controla rotas/cache/headers.

## Mapa de arquivos & rotas

| Arquivo | Rota(s) | Função |
|---|---|---|
| `index.html` | `/`, `/bio`, `/form` | Form de qualificação (4 etapas) → redireciona p/ `/agendar` |
| `lp.html` | `/lp` | Landing page principal + funil "IA" |
| `lp-trafego.html` | `/trafego` | Funil de tráfego pago / gestão de anúncios |
| `agendar.html` | `/agendar` | Agendamento (seg–sex, slots de 90 min, Google Meet) |
| `diagnostico.html` | — | Teste de conexão/escrita no Supabase |
| `vercel.json` | — | Rewrites + cache (`s-maxage`) + headers (`X-Frame-Options`, `X-Content-Type-Options`) |

## Convenções

- **Tudo inline**: cada página tem seu `<style>` e `<script>` no próprio arquivo. Não há CSS/JS externo
  do projeto (só Google Fonts e SDKs da Meta/Vercel).
- **Tema escuro** com gradiente roxo/rosa; cards de opção clicáveis; barra de progresso por etapa.
- **Funções recorrentes por arquivo** (nomes podem variar entre páginas):
  - Validação: nome (anti-fake/sequências de teclado), e-mail (bloqueia descartáveis + sugere correção
    de typo), WhatsApp (valida DDD brasileiro, máscara `(XX) XXXXX-XXXX`).
  - `calculateLeadScore()` / cálculo de `score` + `classification`.
  - Dedupe: checagem no Supabase (e-mail/WhatsApp) + `localStorage`/cookie (validade ~1 ano).
  - Envio: `POST` no Supabase REST + evento para Meta Pixel (`fbq`) e Conversions API (`graph.facebook.com`).
- **Tracking**: captura de `utm_*`, `fbclid`, `gclid`, `entry_point` da URL.
- **Boosters de conversão**: exit-popup, toasts de prova social, barra de urgência, nudge de inatividade.

## Lead scoring — difere por funil ⚠️

Cada página tem seus próprios limiares; **não assuma um valor único**:

| Página | HOT | WARM | COLD |
|---|---|---|---|
| `index.html` | ≥ 140 | ≥ 80 | < 80 |
| `lp.html` | ≥ 110 | ≥ 70 | < 70 (+ rebaixa p/ COLD se orçamento insuficiente / sem compromisso) |
| `lp-trafego.html` | ≥ 120 | ≥ 70 | < 70 |

## Integrações & variáveis

Credenciais ficam **inline no HTML** (não há `.env`). Por serviço (apenas nomes — nunca commitar valores):

- **Supabase** — URL do projeto + `anon key`; tabelas `leads_rise_hub`, `bookings_rise_hub`.
- **Meta** — `PIXEL_ID` (client) + access token da **Conversions API**.
- **Vercel** — Speed Insights / Web Analytics (scripts `/_vercel/...`).

## ⚠️ Known issues / Gotchas

1. **Descasamento de projeto Supabase.** Os HTML apontam para o projeto `ibidukamkkgsurqswsvf`, que
   **não aparece** na conta Supabase conectada às ferramentas (a conta tem "Rise Clinic", "Parana
   Repasses", "Aluni IA"). Antes de mexer em dados, **confirme qual é o projeto correto/atual**.
2. **Token da Meta Conversions API exposto no cliente.** A *anon key* do Supabase ser pública é
   esperado (RLS protege), mas o token da CAPI no HTML é um vazamento real — idealmente movido para um
   backend/edge function. Ao documentar/editar, **não reproduza segredos**.
3. **Sem testes/CI.** Validação é manual (abrir as páginas). Não existe suíte automatizada.

## Ecossistema relacionado (externo — não está neste repo)

O produto SaaS que as landing pages vendem é uma plataforma **multi-tenant de gestão de clínicas com
IA** (em outra base Supabase, "Rise Clinic"): ~26 tabelas incluindo `clinics`, `patients`,
`appointments`, `medical_records`, `scribe_sessions`, `conversations`/`messages`, `campaigns`,
`billing_subscriptions`, com RBAC e planos. Este repositório apenas **alimenta** esse produto com leads.
