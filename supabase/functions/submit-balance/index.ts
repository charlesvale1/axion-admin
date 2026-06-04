import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Content-Type': 'application/json',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const { account_no, balance, equity, profit } = await req.json()

    if (!account_no || balance === undefined) {
      return new Response(JSON.stringify({ ok: false, reason: '파라미터 누락' }), { headers: cors })
    }

    const client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { error } = await client.from('balance_logs').insert({
      account_no: String(account_no),
      balance:    Number(balance),
      equity:     equity  !== undefined ? Number(equity)  : null,
      profit:     profit  !== undefined ? Number(profit)  : null,
      logged_at:  new Date().toISOString(),
    })

    if (error) {
      console.error('submit-balance insert error:', error)
      return new Response(JSON.stringify({ ok: false, reason: error.message }), { headers: cors })
    }

    return new Response(JSON.stringify({ ok: true }), { headers: cors })

  } catch (e) {
    console.error('submit-balance error:', e)
    return new Response(JSON.stringify({ ok: false, reason: '서버 오류' }), { headers: cors })
  }
})
