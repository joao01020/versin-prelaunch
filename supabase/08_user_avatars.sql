-- Execute no Supabase de pré-lançamento. Bucket privado: cada usuário lê e altera somente sua própria foto.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('beta-avatars','beta-avatars',false,2097152,array['image/webp'])
on conflict (id) do update set public=false,file_size_limit=2097152,allowed_mime_types=array['image/webp'];

create policy "beta avatars own read" on storage.objects for select to authenticated
using (bucket_id='beta-avatars' and name=(select auth.uid()::text)||'/avatar.webp');
create policy "beta avatars own insert" on storage.objects for insert to authenticated
with check (bucket_id='beta-avatars' and name=(select auth.uid()::text)||'/avatar.webp');
create policy "beta avatars own update" on storage.objects for update to authenticated
using (bucket_id='beta-avatars' and name=(select auth.uid()::text)||'/avatar.webp')
with check (bucket_id='beta-avatars' and name=(select auth.uid()::text)||'/avatar.webp');
