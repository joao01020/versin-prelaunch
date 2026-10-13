-- Execute APÓS 01, 02 e 03 NO SUPABASE EXCLUSIVO DO PRÉ-LANÇAMENTO.
-- LOGIN: Supabase Auth por e-mail verificado; nenhuma leitura direta da tabela de inscrição.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.versin_admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
revoke all on private.versin_admins from public, anon, authenticated;

-- A associação usa o e-mail do usuário autenticado via Auth, e NÃO um parâmetro controlado pelo navegador.
create or replace function public.versin_my_beta_request()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_email text; v_row record;
begin
 if auth.uid() is null then raise exception 'Não autenticado'; end if;
 select lower(u.email) into v_email from auth.users u
 where u.id=auth.uid() and u.email_confirmed_at is not null;
 if v_email is null then raise exception 'E-mail não confirmado'; end if;
 select id,name,queue_position,status into v_row from public.versin_beta_requests
 where email=v_email limit 1;
 if not found then return jsonb_build_object('found',false); end if;
 return jsonb_build_object('found',true,'name',v_row.name,'queue_position',v_row.queue_position,'status',v_row.status,'request_id',v_row.id);
end $$;
revoke all on function public.versin_my_beta_request() from public,anon;
grant execute on function public.versin_my_beta_request() to authenticated;

-- Somente IDs de administradores cadastrados nesta tabela acessam dados de todos os inscritos.
create or replace function public.versin_admin_beta_requests()
returns table(queue_position bigint,name text,email text,phone text,prefer_phone boolean,role text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
 if auth.uid() is null or not exists(select 1 from private.versin_admins a where a.user_id=auth.uid()) then
   raise exception 'Acesso negado' using errcode = '42501';
 end if;
 return query select r.queue_position,r.name,r.email,r.phone,r.prefer_phone,r.role,r.status,r.created_at
 from public.versin_beta_requests r order by r.queue_position;
end $$;
revoke all on function public.versin_admin_beta_requests() from public,anon;
grant execute on function public.versin_admin_beta_requests() to authenticated;
-- Após fazer login, veja seu UUID no Supabase Authentication > Users e conceda admin via SQL Editor:
-- insert into private.versin_admins(user_id) values ('COLE-SEU-UID-AQUI');
