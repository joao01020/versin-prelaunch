-- Execute depois de 01_waitlist.sql, no mesmo Supabase do VERSIN.
-- Fila de inscrição: primeiras 20 solicitações válidas têm prioridade.
-- ATENÇÃO: não concede autenticação, acesso PRO nem emblemas.

alter table public.versin_beta_requests
  add column if not exists queue_position bigint;

-- Preserve ordem de inscrições antigas, quando existirem.
with ordered as (
  select id, row_number() over (order by created_at, id) as position
  from public.versin_beta_requests
)
update public.versin_beta_requests r
set queue_position = o.position
from ordered o
where r.id = o.id and r.queue_position is null;

create unique index if not exists versin_beta_requests_queue_position_unique
on public.versin_beta_requests(queue_position);

-- Para evitar corridas, a função serializa inscrições com um lock transacional.
-- Não divulgar ou aceitar uma posição enviada pelo cliente.
-- Removemos a assinatura antiga: PostgreSQL não permite alterar só o retorno com CREATE OR REPLACE.
drop function if exists public.request_versin_beta(text, text, text);
create function public.request_versin_beta(p_name text, p_email text, p_role text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_email text := lower(trim(p_email));
  v_name text := trim(p_name);
  v_position bigint;
begin
  if char_length(v_name) not between 2 and 70
    or char_length(v_email) not between 5 and 254
    or v_email !~ '^[^ @]+@[^ @]+\.[^ @]+$'
    or p_role not in ('compositor','artista','produtor','entusiasta','outro') then
    raise exception 'Dados invalidos';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(48117, 501);

  if exists (select 1 from public.versin_beta_requests where email = v_email) then
    return 'registered';
  end if;

  select coalesce(max(queue_position), 0) + 1 into v_position
  from public.versin_beta_requests;

  insert into public.versin_beta_requests (name,email,role,queue_position)
  values (v_name,v_email,p_role,v_position);

  if v_position <= 20 then return 'priority'; end if;
  return 'waiting';
end;
$$;
revoke all on function public.request_versin_beta(text,text,text) from public;
grant execute on function public.request_versin_beta(text,text,text) to anon, authenticated;

-- IMPORTANTE: RPC publica ainda precisa de anti-bot, rate limit e protecao
-- contra inscricoes com emails de terceiros (confirmacao de email).
-- Nao envie convite de login sem confirmar que o email pertence ao inscrito.
