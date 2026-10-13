-- Rode no SQL Editor do MESMO projeto Supabase usado pelo VERSIN.
-- Lista de solicitações; não concede login, Founders nem PRO automaticamente.
create table if not exists public.versin_beta_requests (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 2 and 70),
 email text not null,
 role text not null check (role in ('compositor','artista','produtor','entusiasta','outro')),
 status text not null default 'pending' check (status in ('pending','invited','testing','founder','rejected')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint versin_beta_requests_email_unique unique(email)
);
create index if not exists versin_beta_requests_status_idx on public.versin_beta_requests(status);
alter table public.versin_beta_requests enable row level security;
revoke all on table public.versin_beta_requests from anon, authenticated;

-- Inscrição publica via RPC. Envie somente dados minimamente necessários.
-- API pode sofrer spam: antes de abrir inscrições em escala adicione CAPTCHA/rate limit (Cloudflare Turnstile + Edge Function).
create or replace function public.request_versin_beta(p_name text, p_email text, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(p_email));
  v_name text := trim(p_name);
begin
  if char_length(v_name) not between 2 and 70 or char_length(v_email) not between 5 and 254
     or v_email !~ '^[^ @]+@[^ @]+\.[^ @]+$'
     or p_role not in ('compositor','artista','produtor','entusiasta','outro') then
    raise exception 'Dados inválidos';
  end if;
  insert into public.versin_beta_requests (name,email,role)
  values (v_name,v_email,p_role)
  on conflict (email) do nothing;
end;
$$;
revoke all on function public.request_versin_beta(text,text,text) from public;
grant execute on function public.request_versin_beta(text,text,text) to anon, authenticated;

-- CONTROLE DE VAGAS: aprovar manualmente, via painel Supabase/SQL Editor.
-- O limite de 20 testadores na primeira fase e 50 Founders totais deve
-- ser checado/garantido no backend antes de mudar status e atribuir benefícios.
-- Nunca determine Founder apenas pelo envio deste formulário.
