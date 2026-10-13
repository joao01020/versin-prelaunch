-- VERSIN Beta: painel administrativo com autorização no servidor.
-- Execute após 04_accounts_dashboard.sql no Supabase separado de pré-lançamento.
-- Nunca coloque a chave service_role no Astro.

create or replace function public.versin_admin_set_request_status(
  p_request_id uuid, p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row record;
begin
  if auth.uid() is null or not exists (
    select 1 from private.versin_admins a where a.user_id = auth.uid()
  ) then
    raise exception 'Acesso negado' using errcode = '42501';
  end if;
  if p_status is null or p_status not in ('pending','invited','testing','founder','rejected') then
    raise exception 'Status inválido' using errcode = '22023';
  end if;
  -- A condição "founder" não concede automaticamente benefícios PRO no aplicativo.
  update public.versin_beta_requests
  set status = p_status, updated_at = now()
  where id = p_request_id
  returning id, status, updated_at into v_row;
  if not found then
    raise exception 'Inscrição não encontrada' using errcode = 'P0002';
  end if;
  return jsonb_build_object('id',v_row.id,'status',v_row.status,'updated_at',v_row.updated_at);
end;
$$;
revoke all on function public.versin_admin_set_request_status(uuid,text) from public,anon;
grant execute on function public.versin_admin_set_request_status(uuid,text) to authenticated;

-- A consulta administrativa precisa incluir o id para alterações específicas.
drop function if exists public.versin_admin_beta_requests();
create function public.versin_admin_beta_requests()
returns table(id uuid,queue_position bigint,name text,email text,phone text,prefer_phone boolean,role text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from private.versin_admins a where a.user_id = auth.uid()
  ) then
    raise exception 'Acesso negado' using errcode = '42501';
  end if;
  return query select r.id,r.queue_position,r.name,r.email,r.phone,r.prefer_phone,r.role,r.status,r.created_at
  from public.versin_beta_requests r order by r.queue_position;
end;
$$;
revoke all on function public.versin_admin_beta_requests() from public,anon;
grant execute on function public.versin_admin_beta_requests() to authenticated;
