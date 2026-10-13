-- Execute APÓS 01_waitlist.sql e 02_queue_priority.sql no mesmo projeto Supabase.
-- IDs UUID v4 gerados no servidor; números de fila atribuídos sob lock transacional.
-- Não publica dados pessoais, telefones ou IDs existentes.
alter table public.versin_beta_requests add column if not exists phone text;
alter table public.versin_beta_requests add column if not exists prefer_phone boolean not null default false;

-- Remover apenas a assinatura antiga conhecida, para mudar o retorno da RPC.
drop function if exists public.request_versin_beta(text,text,text);

create function public.request_versin_beta(
 p_name text, p_email text, p_role text,
 p_prefer_phone boolean default false, p_phone text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
 v_email text := lower(trim(p_email));
 v_name text := trim(p_name);
 v_phone text := nullif(trim(coalesce(p_phone,'')), '');
 v_position bigint;
 v_id uuid;
begin
 if char_length(v_name) not between 2 and 70 or char_length(v_email) not between 5 and 254
  or v_email !~ '^[^ @]+@[^ @]+\.[^ @]+$'
  or p_role not in ('compositor','artista','produtor','entusiasta','outro')
  or (coalesce(p_prefer_phone,false) and (v_phone is null or v_phone !~ '^\+?[0-9 ()-]{10,20}$'))
 then raise exception 'Dados de inscrição inválidos'; end if;
 if not coalesce(p_prefer_phone,false) then v_phone := null; end if;
 perform pg_catalog.pg_advisory_xact_lock(48117,501);
 if exists(select 1 from public.versin_beta_requests where email=v_email) then
   -- Não revela ID/posição de outra pessoa a quem conhece apenas seu e-mail.
   return jsonb_build_object('status','registered');
 end if;
 select coalesce(max(queue_position),0)+1 into v_position from public.versin_beta_requests;
 insert into public.versin_beta_requests(name,email,role,queue_position,prefer_phone,phone)
 values(v_name,v_email,p_role,v_position,coalesce(p_prefer_phone,false),v_phone)
 returning id into v_id;
 return jsonb_build_object('status','created','queue_position',v_position,'request_id',v_id,'first_group',v_position<=20);
end $$;
revoke all on function public.request_versin_beta(text,text,text,boolean,text) from public;
grant execute on function public.request_versin_beta(text,text,text,boolean,text) to anon, authenticated;

-- Estatísticas públicas agregadas: sem expor dados de contato.
create or replace function public.versin_beta_queue_stats()
returns jsonb language sql stable security definer set search_path = ''
as $$
 select jsonb_build_object(
   'total', count(*),
   'remaining_first_group', greatest(20 - count(*),0),
   'first_group_capacity',20
 ) from public.versin_beta_requests;
$$;
revoke all on function public.versin_beta_queue_stats() from public;
grant execute on function public.versin_beta_queue_stats() to anon, authenticated;

-- Antes de publicar: proteger inscrições com Turnstile + rate limiting no servidor,
-- confirmar posse do e-mail e restringir distribuição de convites de login.
