-- =============================================================================
-- 0004_heatmap.sql — Heatmap custom /lp2 (isolado do funil/leads/bookings).
-- Postura do projeto: anon SO INSERT; leitura so via RPC SECURITY DEFINER.
-- Privacidade: ZERO PII (session efemera por aba; so tag/id/classe do elemento).
-- Aditiva: nao toca leads_rise_hub/bookings_rise_hub nem RPCs existentes.
--
-- IMPORTANTE: o TOKEN real do viewer NAO fica aqui. Depois de aplicar, rode 1x
-- (no SQL Editor, NAO versionado):
--   update public.heatmap_config
--      set token_hash = encode(digest('SEU_TOKEN_ALEATORIO','sha256'),'hex')
--    where page = 'lp2';
-- e acesse o viewer em /lp2#heatmap=SEU_TOKEN
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---- TABELA DE EVENTOS (append-only, sem PII) -------------------------------
create table if not exists public.heatmap_events (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  session_id text        not null,                 -- id anonimo por aba (nao e lead)
  page       text        not null default 'lp2',
  event_type text        not null,                 -- 'click' | 'rage' | 'scroll'
  x_bp       smallint,                             -- basis points 0..10000 da LARGURA do doc
  y_bp       smallint,                             -- basis points 0..10000 da ALTURA do doc
  device     text        not null,                 -- 'mobile' | 'tablet' | 'desktop'
  vw         smallint,
  vh         smallint,
  dpr        real,
  tgt        text,                                 -- seletor sanitizado (tag/id/classe); nunca valor/PII
  constraint hm_type_ck   check (event_type in ('click','rage','scroll')),
  constraint hm_device_ck check (device in ('mobile','tablet','desktop')),
  constraint hm_x_ck      check (x_bp is null or x_bp between 0 and 10000),
  constraint hm_y_ck      check (y_bp is null or y_bp between 0 and 10000),
  constraint hm_sid_ck    check (length(session_id) <= 64),
  constraint hm_tgt_ck    check (tgt is null or length(tgt) <= 80)
);

create index if not exists hm_events_agg_idx
  on public.heatmap_events (page, event_type, device, created_at)
  include (x_bp, y_bp, session_id);
create index if not exists hm_events_created_brin
  on public.heatmap_events using brin (created_at);

-- ---- CONFIG / TOKEN (apenas HASH; anon nunca enxerga) -----------------------
create table if not exists public.heatmap_config (
  page       text primary key,
  token_hash text not null,
  enabled    boolean not null default true,
  updated_at timestamptz not null default now()
);
-- placeholder invalido (nao e sha256 valido) => nenhum token funciona ate o UPDATE
insert into public.heatmap_config (page, token_hash, enabled)
values ('lp2', 'DEFINIR_VIA_UPDATE', true)
on conflict (page) do nothing;

-- ---- RLS --------------------------------------------------------------------
alter table public.heatmap_events enable row level security;
alter table public.heatmap_config enable row level security;

drop policy if exists hm_anon_insert on public.heatmap_events;
create policy hm_anon_insert on public.heatmap_events
  for insert to anon
  with check (page = 'lp2' and event_type in ('click','rage','scroll')
    and device in ('mobile','tablet','desktop') and length(session_id) <= 64
    and (x_bp is null or x_bp between 0 and 10000)
    and (y_bp is null or y_bp between 0 and 10000));

drop policy if exists hm_auth_all_events on public.heatmap_events;
create policy hm_auth_all_events on public.heatmap_events for all to authenticated using (true) with check (true);

drop policy if exists hm_auth_all_config on public.heatmap_config;
create policy hm_auth_all_config on public.heatmap_config for all to authenticated using (true) with check (true);

-- ---- GRANTS explicitos (anon so INSERT; config nem enxerga) -----------------
revoke all on public.heatmap_events from anon, authenticated;
grant insert on public.heatmap_events to anon;
grant select, insert, update, delete on public.heatmap_events to authenticated;
revoke all on public.heatmap_config from anon, authenticated;
grant select, insert, update, delete on public.heatmap_config to authenticated;

-- ---- RPC unica de leitura agregada em BINS (valida token via hash) ----------
create or replace function public.get_heatmap(
  p_token text, p_page text default 'lp2', p_device text default null,
  p_from timestamptz default now() - interval '30 days', p_to timestamptz default now(),
  p_event text default 'click', p_bins integer default 100
) returns table (bx smallint, biny smallint, weight integer)
language plpgsql stable security definer set search_path = public, extensions, pg_temp
as $$
declare
  v_ok boolean;
  v_bins integer := greatest(20, least(200, coalesce(p_bins, 100)));
  v_bw integer := 10000 / v_bins;
begin
  select exists (select 1 from public.heatmap_config c
    where c.page = p_page and c.enabled
      and c.token_hash = encode(digest(coalesce(p_token,''), 'sha256'), 'hex')) into v_ok;
  if not v_ok then raise exception 'heatmap: token invalido' using errcode = '42501'; end if;
  if p_event not in ('click','rage','scroll') then p_event := 'click'; end if;
  if p_event = 'scroll' then
    return query select 0::smallint, least(v_bins - 1, (s.ymax / v_bw))::smallint, count(*)::int
      from (select e.session_id, max(e.y_bp) as ymax from public.heatmap_events e
            where e.page = p_page and e.event_type = 'scroll' and (p_device is null or e.device = p_device)
              and e.created_at >= p_from and e.created_at < p_to and e.y_bp is not null
            group by e.session_id) s
      group by 2 order by 2;
    return;
  end if;
  return query select least(v_bins - 1, (e.x_bp / v_bw))::smallint, least(v_bins - 1, (e.y_bp / v_bw))::smallint, count(*)::int
    from public.heatmap_events e
    where e.page = p_page and e.event_type = p_event and (p_device is null or e.device = p_device)
      and e.created_at >= p_from and e.created_at < p_to and e.x_bp is not null and e.y_bp is not null
    group by 1, 2 order by 3 desc;
end; $$;

revoke all on function public.get_heatmap(text,text,text,timestamptz,timestamptz,text,integer) from public;
grant execute on function public.get_heatmap(text,text,text,timestamptz,timestamptz,text,integer) to anon, authenticated;

-- ---- (opcional) retencao: manter a tabela pequena --------------------------
-- select cron.schedule('hm_retention','0 4 * * *',
--   $$delete from public.heatmap_events where created_at < now() - interval '90 days'$$);
