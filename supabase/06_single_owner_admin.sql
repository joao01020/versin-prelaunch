-- VERSIN pré-lançamento: somente uma conta administrativa.
-- EXECUTE NO SQL EDITOR com o UID da sua conta em Authentication > Users.
-- IMPORTANTE: troque o UUID abaixo pelo SEU auth.users.id (NÃO o ID da fila).
-- Execute UMA VEZ e revise a conta informada antes de executar.

do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-000000000000'::uuid; -- SUBSTITUA PELO SEU UID
begin
  if v_owner = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'Substitua o UUID de exemplo pelo seu UID em Authentication > Users';
  end if;
  if not exists(select 1 from auth.users where id=v_owner) then
    raise exception 'UID informado não existe em auth.users';
  end if;
  -- Mantém somente o dono na relação privada de administradores.
  delete from private.versin_admins where user_id <> v_owner;
  insert into private.versin_admins(user_id) values (v_owner) on conflict (user_id) do nothing;
end $$;

-- Garante que não sejam inseridos dois administradores, mesmo por engano.
create unique index if not exists versin_single_admin_only
  on private.versin_admins ((true));

-- Nenhuma conta comum pode consultar ou alterar a lista de administradores.
revoke all on schema private from public, anon, authenticated;
revoke all on private.versin_admins from public, anon, authenticated;

-- Observe: o proprietário do banco e usuários privilegiados do Supabase
-- sempre podem fazer mudanças via SQL Editor. Isso não pode ser impedido
-- de forma absoluta por uma política do aplicativo.
