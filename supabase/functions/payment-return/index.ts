// @ts-ignore: esm.sh imports are resolved at runtime by Supabase Edge Functions.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

// @ts-ignore: Deno.env is available at runtime.
const env = (name: string): string | undefined => Deno.env.get(name) ?? undefined

function normalizeStatus(status: string | null): string {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'success':
    case 'successful':
    case 'approved':
    case 'validated':
    case 'complete':
    case 'completed':
    case 'paid':
      return 'completed'
    case 'failed':
    case 'error':
    case 'declined':
      return 'failed'
    case 'cancelled':
    case 'canceled':
    case 'expired':
      return 'cancelled'
    default:
      return (status ?? 'pending').trim().toLowerCase() || 'pending'
  }
}

function isSuccessStatus(status: string | null): boolean {
  return normalizeStatus(status) === 'completed'
}

function page(status: string, synced: boolean): string {
  const isSuccess = isSuccessStatus(status)
  const title = isSuccess && synced
    ? 'Paiement confirme'
    : isSuccess
    ? 'Paiement recu'
    : 'Paiement non confirme'
  const message = isSuccess && synced
    ? 'Votre commande a ete confirmee.'
    : isSuccess
    ? 'Le paiement est recu, mais la commande n a pas encore ete retrouvee.'
    : 'Le paiement n a pas ete finalise.'

  return `<!doctype html>
<html lang="fr">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title>
    <style>
      body {
        align-items: center;
        background: #f7f3ef;
        color: #151515;
        display: flex;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        justify-content: center;
        margin: 0;
        min-height: 100vh;
      }
      main {
        max-width: 360px;
        padding: 24px;
        text-align: center;
      }
      h1 {
        font-size: 22px;
        margin: 0 0 10px;
      }
      p {
        color: #5c554f;
        line-height: 1.5;
        margin: 0;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>${title}</h1>
      <p>${message}</p>
    </main>
  </body>
</html>`
}

function firstQueryParam(url: URL, keys: string[]): string | null {
  for (const key of keys) {
    const value = url.searchParams.get(key)?.trim()
    if (value) return value
  }
  return null
}

function orderIdFromPath(url: URL): string | null {
  const parts = url.pathname.split('/').filter(Boolean)
  for (const part of parts.reverse()) {
    if (isUuid(part)) return part
  }
  return null
}

function isUuid(value: string | null): value is string {
  return !!value &&
    /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
      .test(value)
}

async function resolveOrderId(
  supabase: any,
  orderId: string | null,
  reference: string | null,
): Promise<string | null> {
  if (isUuid(orderId)) return orderId
  if (orderId) {
    console.warn('payment-return ignored invalid order_id', { order_id: orderId })
  }
  if (!reference) return null

  const { data, error } = await supabase
    .from('payments')
    .select('order_id')
    .eq('reference', reference)
    .maybeSingle()

  if (error) {
    console.warn('payment-return order lookup failed', {
      reference,
      code: error.code,
      message: error.message,
    })
    return null
  }

  return data?.order_id ?? null
}

async function applyReturnStatus(
  status: string,
  orderId: string | null,
  reference: string | null,
): Promise<boolean> {
  if (!isSuccessStatus(status)) return false

  const supabaseUrl = env('SUPABASE_URL')
  const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceKey) {
    console.warn('payment-return sync skipped: missing Supabase config')
    return false
  }

  const supabase = createClient(supabaseUrl, serviceKey)
  const now = new Date().toISOString()
  const resolvedOrderId = await resolveOrderId(supabase, orderId, reference)

  if (!resolvedOrderId && !reference) {
    console.warn('payment-return sync skipped: missing order_id/reference')
    return false
  }

  let paymentQuery = supabase
    .from('payments')
    .update({
      status: 'completed',
      status_message: 'Payment return success',
      updated_at: now,
    })
    .in('status', ['pending', 'processing'])

  paymentQuery = reference
    ? paymentQuery.eq('reference', reference)
    : paymentQuery.eq('order_id', resolvedOrderId)

  const { error: paymentError } = await paymentQuery

  if (paymentError) {
    console.warn('payment-return payment sync failed', {
      order_id: resolvedOrderId,
      reference,
      code: paymentError.code,
      message: paymentError.message,
    })
  }

  if (!resolvedOrderId) return false

  const { error: orderError } = await supabase
    .from('orders')
    .update({
      status: 'paid',
      updated_at: now,
    })
    .eq('id', resolvedOrderId)
    .in('status', ['pending_payment', 'pending', 'confirmed'])

  if (orderError) {
    console.warn('payment-return order sync failed', {
      order_id: resolvedOrderId,
      reference,
      code: orderError.code,
      message: orderError.message,
    })
    return false
  }

  return true
}

// @ts-ignore: Deno.serve is available at runtime in Supabase Edge Functions.
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'GET') {
    return new Response('Method not allowed', {
      status: 405,
      headers: corsHeaders,
    })
  }

  const url = new URL(req.url)
  const status = firstQueryParam(url, [
    'status',
    'payment_status',
    'transaction_status',
    'state',
  ]) ?? 'pending'
  const orderId = firstQueryParam(url, ['order_id', 'orderId']) ??
    orderIdFromPath(url)
  const reference = firstQueryParam(url, [
    'reference',
    'transaction_id',
    'payment_reference',
    'payment_id',
  ])

  const synced = await applyReturnStatus(status, orderId, reference)

  return new Response(page(status, synced), {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
    },
  })
})
