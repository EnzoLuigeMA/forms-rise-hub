-- 0003_partial_lead_status.sql
-- Marca leads incompletos do /lp com status 'parcial' (filtravel no CRM) e
-- "gradua" para 'novo' quando a qualificacao e completada.
--
-- Contexto: o /lp salva um lead PARCIAL apos o passo de contato (savePartialLead).
-- Antes, esse parcial entrava como status 'novo', indistinguivel de um lead completo.
-- Agora entra como 'parcial' e so vira 'novo' quando update_lead_qualification roda.

-- 1) Permite o valor 'parcial' no CHECK de status
alter table public.leads_rise_hub drop constraint if exists leads_rise_hub_status_check;
alter table public.leads_rise_hub add constraint leads_rise_hub_status_check
  check (status = any (array['novo','contatado','agendado','proposta_enviada','pausado','convertido','perdido','parcial']));

-- 2) update_lead_qualification: ao completar, parcial -> novo
--    (CREATE OR REPLACE preserva os GRANTs existentes para anon/authenticated)
create or replace function public.update_lead_qualification(
  p_lead_id uuid,
  p_faturamento text default null,
  p_orcamento text default null,
  p_compromisso text default null,
  p_lead_score integer default null,
  p_lead_classification text default null,
  p_observacao text default null
)
returns integer
language plpgsql
security definer
set search_path to 'public','pg_temp'
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
         observacao          = coalesce(p_observacao, observacao),
         status              = case when status = 'parcial' then 'novo' else status end
   where id = p_lead_id;
  get diagnostics n = row_count;
  return n;
end;
$$;
