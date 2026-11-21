# Brief — Páginas por frente de serviço (form.risehub.com.br)

Data: 2026-11-20. Coordenador: Claude (Fable 5.1). Executores: agentes Opus. Revisor: Fable.

## Objetivo
Uma página de vendas por frente de serviço da Rise Hub, no mesmo site estático (`forms-rise-hub`, Vercel,
endereço canônico `https://form.risehub.com.br`), com a mesma qualidade e identidade da `/paginas`
(Páginas Premium). Tudo em pt-BR. Sem build: HTML + CSS + JS puro.

## Contexto da empresa (fonte: doc "Reestruturando a empresa - Rise Hub" e Manual Interno)
- Rise Hub = consultoria de estruturação comercial com método próprio. Promessa setor-agnóstica:
  "transformamos operação comercial manual em motor previsível". Método: **diagnóstico → estrutura → motor → escala**.
- **Não é agência de tráfego.** O diferencial é o Degrau 1: entra medindo (Diagnóstico Comercial gratuito) antes
  de vender execução. Toda comunicação abre pelo diagnóstico, não pelos serviços.
- Escada de oferta (por comprometimento/ticket, o cliente entra no degrau que faz sentido):
  1. **Diagnóstico Comercial** (gratuito) — varre o funil e mede cada etapa: tráfego, atendimento, follow-up, ticket.
  2. **Marketing Tech** — tráfego pago + criativos + páginas. Para quem só quer gerar leads. Sobe quando o gargalo é volume/qualidade de lead.
  3. **Rise Engine** (carro-chefe) — aquisição + agente de IA + implementação comercial. Sobe quando há volume (30+ leads/mês) mas a conversão é baixa.
  4. **Scale-up** — sistemas de IA sob medida + consultoria. Só depois que o motor provou resultado (60-90 dias).
- 7 frentes de serviço (as páginas): tráfego pago, criativos, páginas (Páginas Premium, já existe em `/paginas`),
  agente de IA (Sofia), implementação comercial (processo + CRM + follow-up), sistemas de IA sob medida, consultoria.
- Onde a venda se perde (os 4 vazamentos): leads esquecidos no atendimento, conversa que não vira venda,
  sem follow-up, sem previsibilidade. Sofia responde em segundos, qualifica, agenda e faz follow-up 24/7
  (WhatsApp e Instagram DM), com handoff para humano.
- ICP: já vende mas o processo é manual; investe em aquisição; aceita mudar rotina; "sei que preciso vender mais,
  mas não sei onde está vazando". Não é: quem nunca vendeu, quem decide só por preço, quem não muda processo.
- Camada institucional não lista setores como posicionamento. Pode citar segmentos como exemplo de aplicação
  ("funciona em clínica, imobiliária, pousada…"), nunca como "fazemos tráfego para X".

## Regras duras
- **Sem preços inventados, sem cases/números inventados.** Único preço real: Páginas Premium R$ 597 (já na `/paginas`).
  Métricas permitidas apenas como promessa de processo (ex.: "resposta em segundos", "painel desde o dia 1"),
  nunca "aumentamos X% as vendas de Y".
- Sem segredos no client. Pixel Meta id `2238173290034845` pode ir no HTML (já está nas outras páginas).
- Sem em-dash (—) na copy. Frases curtas, voz direta, técnica e acessível.
- Acessibilidade: contraste AA, foco visível, `alt` real, botões com rótulo, `prefers-reduced-motion`.
- Mobile-first, sem scroll horizontal, fontes carregadas como em `paginas.html` (media=print + onload).

## Identidade visual (copiar de `paginas.html`, linhas 1-200)
Tokens OKLCH violeta/magenta (`--bg`, `--surface`, `--violet`, `--magenta`, `--grad-accent`…), fontes
Clash Display (display) + Hanken Grotesk (corpo) + Geist Mono (eyebrow), `.wrap`, `.eyebrow`, `.lead`, `.btn`,
cards com borda `--border` e raio `--radius`. Logo `/img/logo.webp`. Sofia: `/img/sofia.webp`.
Portfólio real de páginas: `/img/portfolio/*-desktop.webp` e `*-mobile.webp`.

## Mecânica comum de conversão (igual em todas as páginas)
- CTA primário: **"Agendar diagnóstico gratuito"** → `/form?utm_source=site&utm_medium=pagina&utm_campaign=<slug>`
  (o formulário `/form` já grava utm_* no lead).
- CTA secundário: WhatsApp `https://wa.me/5522997810444?text=<mensagem url-encoded citando o serviço>`.
- Pixel: `PageView` + `ViewContent` (`content_name: '<slug>'`, `content_type: 'service'`) com `eventID`
  (copiar o padrão `rhEventId` de `paginas.html`); `Contact` no clique do WhatsApp; `Lead`? NÃO (o /form já dispara).
- Nav fixa igual à `/paginas` (logo + link "Todos os serviços" → `/servicos` + botão CTA). Footer igual, com
  links: Diagnóstico `/form`, Serviços `/servicos`, Instagram `https://www.instagram.com/risehub.br/`, Privacidade `/privacidade`.

## Estrutura padrão de cada página de serviço
1. Hero: eyebrow com o degrau ("Degrau 2 · Marketing Tech"), h1 com `.grad` numa palavra, lead, 2 CTAs, 3 bullets de garantia de processo.
2. O problema (3 dores concretas do dia a dia, sem números).
3. O que entregamos (lista de entregáveis reais; só o que a Rise Hub faz de fato).
4. Como funciona (4 passos, do diagnóstico à operação).
5. Onde entra na escada (qual pacote inclui: Marketing Tech / Rise Engine / Scale-up) + link `/servicos`.
6. Para quem é / não é (ICP acima).
7. FAQ (5 perguntas) com `<details>`.
8. CTA final + footer.

## Páginas e arquivos
| Rota | Arquivo | Frente | Degrau |
|---|---|---|---|
| `/servicos` | `servicos.html` | Hub: escada + 7 frentes com links | todos |
| `/trafego` | `lp-trafego.html` (REESCREVER, hoje é "para clínicas") | Tráfego pago | Marketing Tech |
| `/criativos` | `criativos.html` | Criativos de performance (estático, motion, roteiro) | Marketing Tech |
| `/paginas` | `paginas.html` (existe; só linkar) | Páginas Premium | Marketing Tech |
| `/sofia` | `sofia.html` | Agente de IA Sofia (WhatsApp/Instagram) | Rise Engine |
| `/implementacao` | `implementacao.html` | Implementação comercial: processo, CRM, follow-up, painel | Rise Engine |
| `/sistemas` | `sistemas.html` | Sistemas de IA sob medida (integrações, automações) | Scale-up |
| `/consultoria` | `consultoria.html` | Consultoria de estruturação comercial | Scale-up |

Rotas em `vercel.json` (rewrites `/x` → `/x.html`; redirects `/marketing-tech`, `/rise-engine`, `/scale-up` → `/servicos#...`).

## Base compartilhada
`assets/servico.css` (tokens + componentes comuns) e `assets/servico.js` (nav, pixel com eventID, reveal, FAQ).
Cada página só traz CSS específico inline. Template de referência: `_template-servico.html` (não roteado).
