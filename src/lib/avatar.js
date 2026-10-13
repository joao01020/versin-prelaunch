import { supabase } from './supabase.js';
export async function loadAvatar(userId) {
  if (!supabase || !userId) return null;
  const { data, error } = await supabase.storage.from('beta-avatars').createSignedUrl(`${userId}/avatar.webp`, 120);
  if (error || !data?.signedUrl) return null;
  return data.signedUrl;
}
export function applyAvatar(container, url) {
  if (!container) return;
  container.querySelectorAll('img.user-avatar-photo').forEach(img => img.remove());
  if (!url) return;
  const img = document.createElement('img');
  img.className = 'user-avatar-photo'; img.src = url; img.alt = '';
  img.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;border-radius:50%;position:absolute;inset:0';
  container.style.position = 'relative'; container.style.overflow = 'hidden';
  container.append(img);
}
