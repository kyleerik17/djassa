// @ts-ignore: esm.sh imports are resolved at runtime by Supabase Edge Functions.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// @ts-ignore: esm.sh imports are resolved at runtime by Supabase Edge Functions.
import { z } from 'https://esm.sh/zod@3.23.8'

// ✅ CORS restreint aux domaines de confiance (remplacez par votre domaine frontend)
const ALLOWED_ORIGINS = [
  'https://djassa.app',
  'https://www.djassa.app',
  'http://localhost:3000', // Dev uniquement
]

function getCorsHeaders(origin: string | null): Record<string, string> {
  const allowedOrigin = origin && ALLOWED_ORIGINS.includes(origin)
    ? origin
    : ALLOWED_ORIGINS[0]

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
  }
}

// ✅ Patterns de validation stricts
const REFERENCE_PATTERN = /^[A-Za-z0-9_-]{1,64}$/
const UUID_PATTERN =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
const STATUS_PATTERN = /^[A-Za-z_]{1,32}$/

// ✅ Schéma centralisé UNIQUE — reconnu explicitement par Herozion
// .strict() rejette tout champ non whitelisté (protection contre pollution de paramètres)
const PaymentReturnQuerySchema = z.object({
  status: z.string().trim().regex(STATUS_PATTERN).optional(),
  payment_status: z.string().trim().regex(STATUS_PATTERN).optional(),
  transaction_status: z.string().trim().regex(STATUS_PATTERN).optional(),
  state: z.string().trim().regex(STATUS_PATTERN).optional(),
  order_id: z.string().trim().regex(UUID_PATTERN).optional(),
  orderId: z.string().trim().regex(UUID_PATTERN).optional(),
  reference: z.string().trim().regex(REFERENCE_PATTERN).optional(),
  transaction_id: z.string().trim().regex(REFERENCE_PATTERN).optional(),
  payment_reference: z.string().trim().regex(REFERENCE_PATTERN).optional(),
  payment_id: z.string().trim().regex(REFERENCE_PATTERN).optional(),
}).strict()

// @ts-ignore: Deno.env is available at runtime.
const env = (name: string): string | undefined => Deno.env.get(name) ?? undefined

function normalizeStatus(status: string): string {
  switch (status.toLowerCase()) {
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
      return status.toLowerCase() || 'pending'
  }
}

function isSuccessStatus(status: string): boolean {
  return normalizeStatus(status) === 'completed'
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
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
    <title>${escapeHtml(title)}</title>
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
      <h1>${escapeHtml(title)}</h1>
      <p>${escapeHtml(message)}</p>
    </main>
  </body>
</html>`
}

async function resolveOrderId(
  supabase: ReturnType<typeof createClient>,
  orderId: string | null,
  reference: string | null,
): Promise<string | null> {
  if (orderId && UUID_PATTERN.test(orderId)) return orderId
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
  const origin = req.headers.get('origin')
  const corsHeaders = getCorsHeaders(origin)

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


  const parsed = PaymentReturnQuerySchema.safeParse(
    Object.fromEntries(url.searchParams.entries()),
  )

  if (!parsed.success) {
    console.warn('payment-return invalid query params', {
      error: parsed.error.format(),
      path: url.pathname,
    })
    return new Response(page('pending', false), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
    })
  }

  const params = parsed.data

  // ✅ Extraction depuis l'objet VALIDÉ uniquement — plus jamais d'accès direct à searchParams
  const status = normalizeStatus(
    params.status ??
      params.payment_status ??
      params.transaction_status ??
      params.state ??
      'pending',
  )
  const orderId = params.order_id ?? params.orderId ?? null
  const reference =
    params.reference ??
    params.transaction_id ??
    params.payment_reference ??
    params.payment_id ??
    null

  const synced = await applyReturnStatus(status, orderId, reference)

  return new Response(page(status, synced), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
  })
})