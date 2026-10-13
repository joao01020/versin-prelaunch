-- Executar após 01 a 06 no Supabase EXCLUSIVO do prelaunch.
-- Limite efetivo no banco e funções restritas à conta administrativa.
create table if not exists private.versin_queue_config (
 id integer primary key check (id=1),
 capacity integer not null check (capacity between 1 and 100000),
 updated_at timestamptz not null default now()
);
insert into private.versin_queue_config(id,capacity) values(1,20) on conflict(id) do nothing;
revoke all on private.versin_queue_config from public,anon,authenticated;

create or replace function public.versin_beta_queue_stats()
returns jsonb language sql stable security definer set search_path = '' as $$
 select jsonb_build_object('total',(select count(*) from public.versin_beta_requests),
 'capacity', c.capacity,
 'remaining', greatest(c.capacity-(select count(*) from public.versin_beta_requests),0),
 'first_group_capacity',c.capacity,
 'remaining_first_group',greatest(c.capacity-(select count(*) from public.versin_beta_requests),0))
 from private.versin_queue_config c where c.id=1;
$$;
revoke all on function public.versin_beta_queue_stats() from public,anon;
grant execute on function public.versin_beta_queue_stats() to anon,authenticated;

create or replace function public.request_versin_beta(
 p_name text, p_email text, p_role text,
 p_prefer_phone boolean default false, p_phone text default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_email text := lower(trim(p_email)); v_name text := trim(p_name);
 v_phone text := nullif(trim(coalesce(p_phone,'')),'');
 v_position bigint; v_id uuid; v_count bigint; v_capacity integer;
begin
 if char_length(v_name) not between 2 and 70 or char_length(v_email) not between 5 and 254
 or v_email !~ '^[^ @]+@[^ @]+\.[^ @]+$'
 or p_role not in ('compositor','artista','produtor','entusiasta','outro')
 or (coalesce(p_prefer_phone,false) and (v_phone is null or v_phone !~ '^\+?[0-9 ()-]{10,20}$'))
 then raise exception 'Dados de inscrição inválidos'; end if;
 if not coalesce(p_prefer_phone,false) then v_phone:=null; end if;
 perform pg_catalog.pg_advisory_xact_lock(48117,501);
 if exists(select 1 from public.versin_beta_requests where email=v_email) then
 return jsonb_build_object('status','registered'); end if;
 select capacity into v_capacity from private.versin_queue_config where id=1;
 select count(*) into v_count from public.versin_beta_requests;
 if v_count >= v_capacity then
 return jsonb_build_object('status','full','capacity',v_capacity); end if;
 select coalesce(max(queue_position),0)+1 into v_position from public.versin_beta_requests;
 insert into public.versin_beta_requests(name,email,role,queue_position,prefer_phone,phone)
 values(v_name,v_email,p_role,v_position,coalesce(p_prefer_phone,false),v_phone)
 returning id into v_id;
 return jsonb_build_object('status','created','queue_position',v_position,'request_id',v_id,
 'first_group',v_count < 20);
end $$;
revoke all on function public.request_versin_beta(text,text,text,boolean,text) from public,anon;
grant execute on function public.request_versin_beta(text,text,text,boolean,text) to anon,authenticated;

create or replace function public.versin_is_beta_admin()
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists(select 1 from private.versin_admins where user_id=auth.uid());
$$;
revoke all on function public.versin_is_beta_admin() from public,anon;
grant execute on function public.versin_is_beta_admin() to authenticated;

create or replace function public.versin_admin_set_capacity(p_capacity integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_count bigint;
begin
 if auth.uid() is null or not exists(select 1 from private.versin_admins where user_id=auth.uid()) then
 raise exception 'Acesso negado' using errcode='42501'; end if;
 if p_capacity is null or p_capacity < 1 or p_capacity > 100000 then
 raise exception 'Capacidade inválida' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(48117,501);
 select count(*) into v_count from public.versin_beta_requests;
 if p_capacity < v_count then raise exception 'A capacidade não pode ser menor que o total de inscritos'; end if;
 update private.versin_queue_config set capacity=p_capacity,updated_at=now() where id=1;
 return jsonb_build_object('capacity',p_capacity,'total',v_count,'remaining',p_capacity-v_count);
end $$;
revoke all on function public.versin_admin_set_capacity(integer) from public,anon;
grant execute on function public.versin_admin_set_capacity(integer) to authenticated;

create or replace function public.versin_admin_delete_request(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_pos bigint;
begin
 if auth.uid() is null or not exists(select 1 from private.versin_admins where user_id=auth.uid()) then
 raise exception 'Acesso negado' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(48117,501);
 delete from public.versin_beta_requests where id=p_request_id returning queue_position into v_pos;
 if v_pos is null then raise exception 'Inscrição não encontrada' using errcode='P0002'; end if;
 -- Posições das demais inscrições permanecem imutáveis (podem ter lacunas).
 return jsonb_build_object('deleted',true,'queue_position',v_pos);
end $$;
revoke all on function public.versin_admin_delete_request(uuid) from public,anon;
grant execute on function public.versin_admin_delete_request(uuid) to authenticated;
