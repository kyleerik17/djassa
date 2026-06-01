// @ts-ignore: Deno types are provided at runtime by Supabase Edge Functions.
// @ts-ignore: esm.sh imports are resolved at runtime by Supabase Edge Functions.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

const OFFICIAL_GENIUSPAY_BASE_URL = 'https://geniuspay.ci/api/v1/merchant'

// @ts-ignore: Deno.env is available at runtime.
const env = (name: string): string | undefined => Deno.env.get(name) ?? undefined

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object'
    ? value as Record<string, unknown>
    : null
}

function stringValue(value: unknown): string | null {
  if (typeof value === 'string') {
    const trimmed = value.trim()
    return trimmed.length > 0 ? trimmed : null
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value)
  }
  return null
}

function pickString(
  source: Record<string, unknown>,
  keys: string[],
): string | null {
  for (const key of keys) {
    const value = stringValue(source[key])
    if (value) return value
  }
  return null
}

function normalizeBaseUrl(value: string | undefined): string {
  const raw = (value ?? OFFICIAL_GENIUSPAY_BASE_URL).trim()
  let url = raw || OFFICIAL_GENIUSPAY_BASE_URL

  // Older snippets used pay.genius.ci, which now returns "not found".
  url = url.replace('https://pay.genius.ci', 'https://geniuspay.ci')
  url = url.replace('http://pay.genius.ci', 'https://geniuspay.ci')
  url = url.replace(/\/+$/, '')

  if (url === 'https://geniuspay.ci') {
    return OFFICIAL_GENIUSPAY_BASE_URL
  }

  return url
}

function normalizePaymentStatus(status: string | null): string | null {
  switch ((status ?? '').toLowerCase()) {
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
      return 'cancelled'
    case 'expired':
      return 'cancelled'
    case 'processing':
    case 'initiated':
      return 'processing'
    case 'refunded':
    case 'partially_refunded':
      return 'refunded'
    case 'pending':
      return 'pending'
    default:
      return status?.toLowerCase() ?? null
  }
}

async function applyCompletedPaymentToOrder(
  supabase: any,
  reference: string,
) {
  const { data: payment, error: selectError } = await supabase
    .from('payments')
    .select('order_id')
    .eq('reference', reference)
    .maybeSingle()

  if (selectError || !payment?.order_id) {
    if (selectError) {
      console.warn('Local payment order lookup failed', {
        reference,
        code: selectError.code,
        message: selectError.message,
      })
    }
    return
  }

  const { error: orderError } = await supabase
    .from('orders')
    .update({
      status: 'paid',
      updated_at: new Date().toISOString(),
    })
    .eq('id', payment.order_id)
    .in('status', ['pending_payment', 'pending', 'confirmed'])

  if (orderError) {
    console.warn('Local payment order sync failed', {
      order_id: payment.order_id,
      reference,
      code: orderError.code,
      message: orderError.message,
    })
  }
}

async function syncPaymentToDatabase(
  supabase: any,
  reference: string,
  status: string | null,
  rawData: Record<string, unknown>,
) {
  if (!status || !['completed', 'failed', 'cancelled', 'processing', 'refunded'].includes(status)) {
    return
  }

  const { data: payment, error: selectError } = await supabase
    .from('payments')
    .select('id, order_id, user_id, metadata')
    .eq('reference', reference)
    .maybeSingle()

  if (selectError || !payment) {
    console.warn('Payment status sync skipped', {
      reference,
      status,
      code: selectError?.code,
      message: selectError?.message,
    })
    return
  }

  const existingMetadata = asRecord(payment.metadata) ?? {}
  const { error: paymentError } = await supabase
    .from('payments')
    .update({
      status,
      status_message: `Polling GeniusPay: ${status}`,
      updated_at: new Date().toISOString(),
      metadata: {
        ...existingMetadata,
        geniuspay_status_check: rawData,
        status_checked_at: new Date().toISOString(),
      },
    })
    .eq('id', payment.id)

  if (paymentError) {
    console.warn('Payment status sync failed', {
      reference,
      status,
      code: paymentError.code,
      message: paymentError.message,
    })
    return
  }

  if (status === 'completed' && payment?.order_id) {
    const { error: orderError } = await supabase
      .from('orders')
      .update({
        status: 'paid',
        updated_at: new Date().toISOString(),
      })
      .eq('id', payment.order_id)
      .in('status', ['pending_payment', 'pending', 'confirmed'])

    if (orderError) {
      console.warn('Order payment status sync failed', {
        order_id: payment.order_id,
        reference,
        code: orderError.code,
        message: orderError.message,
      })
    }
  }
}

async function localPaymentStatus(
  supabase: any,
  reference: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from('payments')
    .select('status')
    .eq('reference', reference)
    .maybeSingle()

  if (error || !data?.status) return null

  const status = normalizePaymentStatus(String(data.status))
  if (status === 'completed' ||
      status === 'failed' ||
      status === 'cancelled' ||
      status === 'refunded') {
    return status
  }

  return null
}

// @ts-ignore: Deno.serve is available at runtime in Supabase Edge Functions.
Deno.serve(async (req: Request): Promise<Response> => {
  // ── CORS preflight ─────────────────────────────────────────────
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // ── Only GET is allowed for status checks ──────────────────────
  if (req.method !== 'GET') {
    return json({ error: 'Method not allowed', allowed: 'GET' }, 405)
  }

  try {
    const supabaseUrl = env('SUPABASE_URL')
    const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY')
    const geniusApiKey = env('GENIUSPAY_API_KEY') ?? env('GENIUSPAY_PUBLIC_KEY')
    const geniusApiSecret = env('GENIUSPAY_API_SECRET') ?? env('GENIUSPAY_SECRET_KEY')
    const baseUrl = normalizeBaseUrl(env('GENIUSPAY_BASE_URL'))

    // ── Server configuration check ───────────────────────────────
    if (!supabaseUrl || !serviceKey) {
      return json({ error: 'Server misconfigured' }, 500)
    }

    if (!geniusApiKey || !geniusApiSecret) {
      const missing = [
        ...(!geniusApiKey ? ['GENIUSPAY_API_KEY'] : []),
        ...(!geniusApiSecret ? ['GENIUSPAY_API_SECRET'] : []),
      ]
      return json({
        error: 'GeniusPay credentials missing',
        missing,
      }, 500)
    }

    // ── Optional: authenticate user for extra security ───────────
    const supabase = createClient(supabaseUrl, serviceKey)
    const token = req.headers.get('Authorization')?.replace('Bearer ', '').trim()

    if (token) {
      const { data: userData, error: userError } = await supabase.auth.getUser(token)
      if (userError || !userData?.user) {
        return json({ error: 'Invalid session' }, 401)
      }
    }
    // Note: token is optional → allows public polling if needed

    // ── Extract reference from URL path ──────────────────────────
    const url = new URL(req.url)
    const parts = url.pathname.split('/').filter(Boolean)
    const reference = parts[parts.length - 1]

    if (!reference || reference === 'payment-status') {
      return json({
        error: 'Reference required in URL path',
        example: '/payment-status/MTX-XXXXXXXXXX',
      }, 400)
    }

    // ── Call GeniusPay API to get payment status ─────────────────
    const geniusResponse = await fetch(`${baseUrl}/payments/${reference}`, {
      method: 'GET',
      headers: {
        'X-API-Key': geniusApiKey,
        'X-API-Secret': geniusApiSecret,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    })

    const raw = await geniusResponse.text()
    let parsed: Record<string, unknown> = { raw }
    try {
      parsed = JSON.parse(raw)
    } catch {
      // Keep raw body for logs and controlled error payload
    }

    console.log('GeniusPay status check', {
      reference,
      url: `${baseUrl}/payments/${reference}`,
      status: geniusResponse.status,
      body: parsed,
    })

    // ── Handle GeniusPay API errors ──────────────────────────────
    if (!geniusResponse.ok) {
      const localStatus = await localPaymentStatus(supabase, reference)
      if (localStatus) {
        if (localStatus === 'completed') {
          await applyCompletedPaymentToOrder(supabase, reference)
        }

        return json({
          success: true,
          reference,
          status: localStatus,
          source: 'local',
          genius_status: geniusResponse.status,
        })
      }

      const errorPayload = asRecord(parsed.error) ?? parsed
      return json({
        error: 'GeniusPay status check failed',
        message: stringValue(errorPayload.message) ??
          stringValue(errorPayload.error) ??
          'Payment service unavailable',
        genius_status: geniusResponse.status,
        reference,
      }, geniusResponse.status === 404 ? 404 : 502)
    }

    // ── Extract and return normalized status ─────────────────────
    const data = asRecord(parsed.data) ?? parsed
    const status = normalizePaymentStatus(pickString(data, [
      'status',
      'payment_status',
      'transaction_status',
      'state',
      'scenario',
    ]))
    const completedAt = pickString(data, ['completed_at', 'updated_at'])
    const amount = data.amount ?? data.total

    const localStatus = await localPaymentStatus(supabase, reference)
    if (localStatus) {
      if (localStatus === 'completed') {
        await applyCompletedPaymentToOrder(supabase, reference)
      }

      return json({
        success: true,
        reference,
        status: localStatus,
        amount,
        completed_at: completedAt,
        source: 'local',
      })
    }

    await syncPaymentToDatabase(supabase, reference, status, data)

    return json({
      success: true,
      reference,
      status,
      amount,
      completed_at: completedAt,
      // Forward useful fields for frontend caching/optimization
      metadata: asRecord(data.metadata) ?? null,
      payment_method: pickString(data, ['payment_method', 'gateway']),
    })

  } catch (error) {
    console.error('Edge Function error: payment-status', {
      message: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    })

    return json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500)
  }
})
