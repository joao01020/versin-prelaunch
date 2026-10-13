# VERSIN — Site de pré-lançamento

Landing page em Astro para apresentar o VERSIN e receber solicitações para o Beta.

## O que está pronto
- Página responsiva em português, baseada na logo oficial do VERSIN.
- Apresentação, recursos, programa Founders, etapas 20 → 50 e FAQ.
- Convite de Ouro interativo: ao abrir, anuncia a futura conquista secreta **Enigmatic Founder**. Ainda não inclui enigma nem distribuição de emblemas.
- Formulário com estado desativado **até** a configuração do Supabase.
- RPC SQL para receber pedidos de inscrição; entradas são apenas *pending*.
- Cloudflare Workers configurado para assets estáticos.

## Testar
```bash
npm install
npm run dev
```
Abra `http://localhost:4321`.

## Habilitar inscrições reais
1. No Supabase existente do VERSIN, revise e execute `supabase/01_waitlist.sql` pelo SQL Editor.
2. Copie `.env.example` para `.env` e preencha `PUBLIC_SUPABASE_URL` e `PUBLIC_SUPABASE_PUBLISHABLE_KEY` com chave **pública**. Nunca use `service_role`.
3. Reinicie o servidor Astro. O formulário será habilitado.
4. Confira as solicitações em `public.versin_beta_requests` pelo Supabase Dashboard.
5. **Antes de divulgar amplamente**, inclua verificação anti-bot (Turnstile), rate limiting e políticas de privacidade. A RPC pública não tem essa proteção na versão inicial.

## Regras do programa
- Fase 1: selecionar manualmente até 20 pessoas para testar.
- Fase 2: expandir para até 50 pessoas aprovadas.
- O emblema Founder e o PRO vitalício **não são concedidos automaticamente** ao solicitar vaga.
- A concessão definitiva de Founder/PRO deverá ser integrada ao backend/autorização do Flutter e protegida contra alterações pelo cliente.
- Defina termos sobre vigência, plano PRO e uso justo antes da atribuição.

## Deploy
```bash
npm run build
npx wrangler login
npm run deploy
```
Configure as variáveis `PUBLIC_*` no ambiente de **build** antes de compilar. O conteúdo é gerado estaticamente.

## Ligação com o aplicativo
O projeto Astro está separado do app Flutter. Configure futuramente `PUBLIC_VERSIN_APP_URL` e um botão de login/link para o Flutter Web depois de publicar a aplicação e revisar as chaves de IA. A landing não cria contas no Auth: apenas solicita acesso Beta.

## Importante
- Não publicar `.env`, service_role ou segredos privados.
- A maquete do editor na capa é conceitual, não uma captura do app real.
- Não mostrar contagem de vagas restantes sem consultar o backend.
