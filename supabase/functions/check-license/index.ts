import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Content-Type': 'application/json',
}

function json(data: object, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const { account_no, program_name } = await req.json()

    if (!account_no || !program_name) {
      return json({ authorized: false, reason: '파라미터 누락' })
    }

    const client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Step 1: 계좌 활성 확인 + 만료일
    const { data: customer, error: err1 } = await client
      .from('customers')
      .select('id, expires_at')
      .eq('account_no', String(account_no))
      .eq('is_active', true)
      .maybeSingle()

    if (err1 || !customer) {
      return json({ authorized: false, reason: '미등록/비활성 계좌' })
    }

    const expiresAt = customer.expires_at ? new Date(customer.expires_at) : null
    if (!expiresAt || expiresAt < new Date()) {
      const dateStr = expiresAt ? expiresAt.toISOString().slice(0, 10) : '없음'
      return json({ authorized: false, reason: `라이센스 만료됨 (${dateStr})` })
    }

    // Step 2: customer_programs에서 EA 할당 여부 확인
    const { data: programs, error: err2 } = await client
      .from('customer_programs')
      .select('programs(name)')
      .eq('customer_id', customer.id)

    if (err2 || !programs || programs.length === 0) {
      return json({ authorized: false, reason: '할당된 EA 없음' })
    }

    const found = programs.some(
      (p: any) => p.programs?.name?.toLowerCase() === program_name.toLowerCase()
    )

    if (!found) {
      return json({ authorized: false, reason: `이 EA 미할당 (${program_name})` })
    }

    const expireStr = expiresAt.toISOString().slice(0, 10)
    return json({
      authorized: true,
      expires_at: expireStr,
      reason: `라이센스 OK (만료: ${expireStr})`
    })

  } catch (e) {
    console.error('check-license error:', e)
    return json({ authorized: false, reason: '서버 오류' }, 500)
  }
})
