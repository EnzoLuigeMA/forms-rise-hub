-- Briefing dos clientes das Páginas Premium (formulário /paginas/briefing).
--
-- Desenho de acesso (mesma convenção do resto do projeto):
--   * schema `paginas_premium` NÃO é exposto na API; RLS ligado e sem policy => anon não lê nada.
--   * o formulário grava por uma única RPC SECURITY DEFINER em `public`.
--   * arquivos vão para o bucket PRIVADO `paginas-briefing`; anon só pode INSERIR
--     (não lista, não baixa, não sobrescreve). A equipe acessa pelo dashboard / service role.

create schema if not exists paginas_premium;

create table if not exists paginas_premium.briefings (
  id                uuid primary key,
  created_at        timestamptz not null default now(),
  status            text not null default 'novo'
                    check (status in ('novo', 'em_producao', 'entregue', 'cancelado')),
  empresa_nome      text not null,
  responsavel_nome  text not null,
  whatsapp          text not null,
  email             text not null,
  cnpj_cpf          text,
  instagram         text,
  segmento          text,
  cidade_uf         text,
  respostas         jsonb not null,          -- formulário completo, campo a campo
  consentimento_em  timestamptz not null,    -- aceite LGPD
  user_agent        text,
  notas_internas    text
);

create table if not exists paginas_premium.briefing_arquivos (
  id             bigint generated always as identity primary key,
  briefing_id    uuid not null references paginas_premium.briefings(id) on delete cascade,
  categoria      text not null check (categoria in ('logo', 'fotos', 'marca', 'depoimentos', 'outros')),
  caminho        text not null unique,       -- caminho do objeto no bucket paginas-briefing
  nome_original  text not null,
  mime           text,
  tamanho_bytes  bigint,
  created_at     timestamptz not null default now()
);

create index if not exists briefing_arquivos_briefing_id_idx
  on paginas_premium.briefing_arquivos (briefing_id);
create index if not exists briefings_created_at_idx
  on paginas_premium.briefings (created_at desc);

alter table paginas_premium.briefings enable row level security;
alter table paginas_premium.briefing_arquivos enable row level security;

revoke all on schema paginas_premium from anon, authenticated;
revoke all on all tables in schema paginas_premium from anon, authenticated;

-- ---------- Bucket privado para logo, fotos e materiais ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'paginas-briefing', 'paginas-briefing', false, 52428800,   -- 50 MB por arquivo
  array[
    'image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/svg+xml', 'image/heic', 'image/heif',
    'application/pdf', 'application/zip', 'application/x-zip-compressed',
    'application/postscript', 'image/vnd.adobe.photoshop',
    'video/mp4', 'video/quicktime'
  ]
)
on conflict (id) do nothing;

-- anon só insere, e só dentro de uma pasta cujo nome é um UUID (o id do briefing)
drop policy if exists paginas_briefing_upload on storage.objects;
create policy paginas_briefing_upload on storage.objects
  for insert to anon, authenticated
  with check (
    bucket_id = 'paginas-briefing'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  );

-- ---------- RPC de envio ----------
create or replace function public.paginas_briefing_enviar(
  p_id uuid,
  p_dados jsonb,
  p_arquivos jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa      text := nullif(btrim(p_dados->>'empresa_nome'), '');
  v_responsavel  text := nullif(btrim(p_dados->>'responsavel_nome'), '');
  v_whatsapp     text := nullif(btrim(p_dados->>'whatsapp'), '');
  v_email        text := nullif(btrim(p_dados->>'email'), '');
  v_arq          jsonb;
  v_caminho      text;
  v_inseriu      int;
begin
  if p_id is null or p_dados is null or jsonb_typeof(p_dados) <> 'object' then
    raise exception 'briefing invalido';
  end if;
  if v_empresa is null or v_responsavel is null or v_whatsapp is null or v_email is null then
    raise exception 'campos obrigatorios ausentes';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'email invalido';
  end if;
  if coalesce((p_dados->>'consentimento')::boolean, false) is not true then
    raise exception 'consentimento obrigatorio';
  end if;
  if octet_length(p_dados::text) > 200000 then
    raise exception 'briefing grande demais';
  end if;
  if jsonb_typeof(p_arquivos) <> 'array' or jsonb_array_length(p_arquivos) > 80 then
    raise exception 'lista de arquivos invalida';
  end if;

  insert into paginas_premium.briefings (
    id, empresa_nome, responsavel_nome, whatsapp, email,
    cnpj_cpf, instagram, segmento, cidade_uf, respostas, consentimento_em, user_agent
  ) values (
    p_id, left(v_empresa, 200), left(v_responsavel, 200), left(v_whatsapp, 40), left(v_email, 200),
    left(nullif(btrim(p_dados->>'cnpj_cpf'), ''), 40),
    left(nullif(btrim(p_dados->>'instagram'), ''), 200),
    left(nullif(btrim(p_dados->>'segmento'), ''), 200),
    left(nullif(btrim(p_dados->>'cidade_uf'), ''), 200),
    p_dados - 'user_agent', now(), left(p_dados->>'user_agent', 400)
  )
  on conflict (id) do nothing;
  get diagnostics v_inseriu = row_count;

  -- id repetido: não sobrescreve um briefing existente (reenvio do mesmo formulário)
  if v_inseriu = 0 then
    return jsonb_build_object('ok', true, 'duplicado', true);
  end if;

  for v_arq in select * from jsonb_array_elements(p_arquivos) loop
    v_caminho := v_arq->>'caminho';
    -- só registra arquivo que está na pasta deste briefing e que realmente foi enviado
    if v_caminho is null
       or v_caminho not like p_id::text || '/%'
       or not exists (
         select 1 from storage.objects o
         where o.bucket_id = 'paginas-briefing' and o.name = v_caminho
       ) then
      continue;
    end if;
    insert into paginas_premium.briefing_arquivos (briefing_id, categoria, caminho, nome_original, mime, tamanho_bytes)
    values (
      p_id,
      case when v_arq->>'categoria' in ('logo', 'fotos', 'marca', 'depoimentos', 'outros')
           then v_arq->>'categoria' else 'outros' end,
      v_caminho,
      left(coalesce(v_arq->>'nome_original', v_caminho), 300),
      left(v_arq->>'mime', 120),
      nullif(v_arq->>'tamanho_bytes', '')::bigint
    )
    on conflict (caminho) do nothing;
  end loop;

  return jsonb_build_object('ok', true, 'duplicado', false);
end;
$$;

revoke all on function public.paginas_briefing_enviar(uuid, jsonb, jsonb) from public;
grant execute on function public.paginas_briefing_enviar(uuid, jsonb, jsonb) to anon, authenticated;
