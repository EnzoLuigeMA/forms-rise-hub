-- =============================================================================
-- PART 1 — RPCs seguras (SECURITY DEFINER) que substituem o acesso direto do anon
-- =============================================================================
-- É ADITIVO: não quebra nada. Rode PRIMEIRO, antes de ligar o RLS (0002).
-- Aplicar em: Supabase Dashboard > projeto "Forms Rise Hub" (ibidukamkkgsurqswsvf)
--             > SQL Editor > colar e executar.
-- =============================================================================

-- 1) Checagem de lead duplicado -> devolve só boolean (NÃO vaza dados da tabela)
create or replace function public.lead_exists(
  p_email    text default null,
  p_whatsapp text default null
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.leads_rise_hub
    where (p_email    is not null and p_email    <> '' and lower(email) = lower(p_email))
       or (p_whatsapp is not null and p_whatsapp <> '' and whatsapp = p_whatsapp)
  );
$$;

-- 2) Horários ocupados para a tela de agendamento -> só booking_date + duração (sem PII)
create or replace function public.get_available_slots(
  p_from timestamptz,
  p_to   timestamptz
)
returns table (booking_date timestamptz, duration_minutes integer)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select booking_date::timestamptz, duration_minutes::integer
  from public.bookings_rise_hub
  where status = 'confirmado'
    and booking_date >= p_from
    and booking_date <= p_to;
$$;

-- 3) Marca o lead como "agendado" (por id OU email) -> sem expor a tabela
create or replace function public.mark_lead_scheduled(
  p_notas   text,
  p_lead_id uuid default null,
  p_email   text default null
)
returns integer
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  n integer;
begin
  update public.leads_rise_hub
     set status = 'agendado',
         notas_internas = p_notas
   where (p_lead_id is not null and id = p_lead_id)
      or (p_email   is not null and p_email <> '' and lower(email) = lower(p_email));
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 4) Profiling progressivo (LP): completa os campos de qualificação do lead parcial.
--    Atualiza SOMENTE estas colunas, e só por id (sem expor a tabela).
create or replace function public.update_lead_qualification(
  p_lead_id            uuid,
  p_faturamento        text default null,
  p_orcamento          text default null,
  p_compromisso        text default null,
  p_lead_score         integer default null,
  p_lead_classification text default null,
  p_observacao         text default null
)
returns integer
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  n integer;
begin
  update public.leads_rise_hub
     set faturamento         = coalesce(p_faturamento, faturamento),
         orcamento           = coalesce(p_orcamento, orcamento),
         compromisso         = coalesce(p_compromisso, compromisso),
         lead_score          = coalesce(p_lead_score, lead_score),
         lead_classification = coalesce(p_lead_classification, lead_classification),
         observacao          = coalesce(p_observacao, observacao)
   where id = p_lead_id;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Permissões: público NÃO executa; anon/authenticated podem EXECUTAR as RPCs.
revoke all on function public.lead_exists(text, text)                        from public;
revoke all on function public.get_available_slots(timestamptz, timestamptz)  from public;
revoke all on function public.mark_lead_scheduled(text, uuid, text)          from public;
revoke all on function public.update_lead_qualification(uuid, text, text, text, integer, text, text) from public;

grant execute on function public.lead_exists(text, text)                       to anon, authenticated;
grant execute on function public.get_available_slots(timestamptz, timestamptz) to anon, authenticated;
grant execute on function public.mark_lead_scheduled(text, uuid, text)         to anon, authenticated;
grant execute on function public.update_lead_qualification(uuid, text, text, text, integer, text, text) to anon, authenticated;
