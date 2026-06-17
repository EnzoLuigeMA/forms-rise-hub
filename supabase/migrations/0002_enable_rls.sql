-- =============================================================================
-- PART 2 — Fecha o vazamento: ativa RLS e remove leitura/escrita direta do anon
-- =============================================================================
-- ATENÇÃO À ORDEM: rode SOMENTE depois de
--   (1) aplicar 0001_create_rpcs.sql, e
--   (2) ter feito deploy do client novo (index/lp/lp-trafego/agendar) que usa as RPCs.
-- Caso contrário a tela de agendamento e o update de status param de funcionar
-- até o deploy do client novo.
-- =============================================================================

-- Remove TODAS as policies atuais das duas tabelas (inclui a permissiva que hoje
-- deixa qualquer um com a anon key LER todos os leads/agendamentos).
do $$
declare
  pol record;
begin
  for pol in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('leads_rise_hub', 'bookings_rise_hub')
  loop
    execute format('drop policy if exists %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end $$;

-- Garante RLS ligado nas duas tabelas
alter table public.leads_rise_hub    enable row level security;
alter table public.bookings_rise_hub enable row level security;

-- Única operação direta permitida ao anon: INSERIR (formulário + agendamento).
-- SELECT / UPDATE / DELETE diretos ficam BLOQUEADOS -> leitura e update só via RPCs.
-- (service_role — usado pelo CRM/dashboard/backend — ignora RLS e mantém acesso total.)
create policy anon_insert_leads
  on public.leads_rise_hub
  for insert to anon
  with check (true);

create policy anon_insert_bookings
  on public.bookings_rise_hub
  for insert to anon
  with check (true);

-- -----------------------------------------------------------------------------
-- Verificação rápida (rode separado para conferir o resultado):
--   select tablename, rowsecurity from pg_tables
--   where schemaname='public' and tablename in ('leads_rise_hub','bookings_rise_hub');
--   select tablename, policyname, cmd, roles from pg_policies
--   where schemaname='public' and tablename in ('leads_rise_hub','bookings_rise_hub');
-- Teste com a anon key (deve voltar VAZIO / erro de permissão, não dados):
--   GET /rest/v1/leads_rise_hub?select=id&limit=1
-- -----------------------------------------------------------------------------
