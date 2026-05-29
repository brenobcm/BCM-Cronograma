// ============================================================
// BCM Cronograma · Edge Function: create-user
// Supabase Dashboard → Edge Functions → New Function
// Nome: create-user → cole este código → Deploy
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Sem autorização')

    // Cliente admin (usa service_role - seguro pois está no servidor)
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Cliente do usuário que fez a chamada (valida que é admin)
    const caller = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user: callerUser } } = await caller.auth.getUser()
    if (!callerUser) throw new Error('Não autenticado')

    const { data: profile } = await caller.from('profiles').select('role').eq('id', callerUser.id).single()
    if (profile?.role !== 'admin') throw new Error('Apenas admin pode criar usuários')

    const { email, password, name, role } = await req.json()
    if (!email || !password) throw new Error('Email e senha são obrigatórios')

    // Cria o usuário via Admin API
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      user_metadata: { name },
      email_confirm: true,
    })
    if (error) throw error

    // Atualiza perfil (trigger criou com role=tecnico, ajusta aqui)
    await admin.from('profiles').update({ role: role || 'tecnico', name }).eq('id', data.user.id)

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...CORS, 'Content-Type': 'application/json' }
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' }
    })
  }
})
