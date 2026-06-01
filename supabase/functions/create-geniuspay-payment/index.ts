// @ts-ignore: Deno types are provided at runtime by Supabase Edge Functions.
// @ts-ignore: esm.sh imports are resolved at runtime by Supabase Edge Functions.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const OFFICIAL_GENIUSPAY_BASE_URL = 'https://geniuspay.ci/api/v1/merchant'

// @ts-ignore: Deno.env is available at runtime.
const env = (name: string): string | undefined => Deno.env.get(name) ??
  undefined

type PaymentRequest = {
  order_id?: string
  provider?: string
  customer_phone?: string
  customer_name?: string
}

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

function functionsBaseUrl(req: Request, supabaseUrl: string): string {
  const explicit = (env('SUPABASE_FUNCTIONS_URL') ??
    env('SUPABASE_FUNCTION_URL') ??
    '').trim()

  if (explicit) return explicit.replace(/\/+$/, '')

  try {
    const url = new URL(req.url)
    url.protocol = 'https:'
    return `${url.origin}/functions/v1`
  } catch {
    return `${supabaseUrl.replace(/\/+$/, '').replace(/^http:/, 'https:')}/functions/v1`
  }
}

function paymentReturnUrl(
  functionsUrl: string,
  status: 'success' | 'failed',
  orderId: string,
): string {
  const url = new URL(`${functionsUrl}/payment-return/${orderId}`)
  url.searchParams.set('status', status)
  url.searchParams.set('order_id', orderId)
  return url.toString()
}

function withReturnParams(
  rawUrl: string,
  status: 'success' | 'failed',
  orderId: string,
): string {
  try {
    const url = new URL(rawUrl)
    url.protocol = 'https:'
    if (!url.pathname.endsWith(`/${orderId}`)) {
      url.pathname = `${url.pathname.replace(/\/+$/, '')}/${orderId}`
    }
    if (!url.searchParams.get('status')) {
      url.searchParams.set('status', status)
    }
    url.searchParams.set('order_id', orderId)
    return url.toString()
  } catch {
    return rawUrl
  }
}

function normalizeProvider(provider: string): string {
  const normalized = provider.trim().toLowerCase()
  const allowed = new Set([
    'wave',
    'orange_money',
    'moov_money',
    'mtn_money',
    'geniuspay',
  ])
  return allowed.has(normalized) ? normalized : 'geniuspay'
}

function providerRouting(provider: string): Record<string, string> {
  switch (provider) {
    case 'wave':
      return { payment_method: 'wave' }
    case 'orange_money':
      return { payment_method: 'orange_money' }
    case 'mtn_money':
      return { payment_method: 'mtn_money' }
    case 'moov_money':
      return { gateway: 'moov_money' }
    default:
      return {}
  }
}

async function readJsonBody(req: Request): Promise<PaymentRequest | null> {
  try {
    return await req.json() as PaymentRequest
  } catch {
    return null
  }
}

// @ts-ignore: Deno.serve is available at runtime in Supabase Edge Functions.
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  try {
    const supabaseUrl = env('SUPABASE_URL')
    const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY')
    // Public key, for example pk_live_xxx or pk_sandbox_xxx.
    const geniusApiKey = env('GENIUSPAY_API_KEY') ??
      env('GENIUSPAY_PUBLIC_KEY') ??
      env('GENIUSPAY_PUBLIC')
    // Secret key, for example sk_live_xxx or sk_sandbox_xxx.
    const geniusApiSecret = env('GENIUSPAY_API_SECRET') ??
      env('GENIUSPAY_SECRET_KEY') ??
      env('GENIUSPAY_SECRET') ??
      env('GENIUSPAY_API_SECRETE')
    const baseUrl = normalizeBaseUrl(env('GENIUSPAY_BASE_URL'))

    if (!supabaseUrl || !serviceKey) {
      return json({ error: 'Server misconfigured' }, 500)
    }

    if (!geniusApiKey || !geniusApiSecret) {
      const missingCredentials = [
        ...(!geniusApiKey ? ['GENIUSPAY_API_KEY'] : []),
        ...(!geniusApiSecret ? ['GENIUSPAY_API_SECRET'] : []),
      ]
      return json({
        error: 'GeniusPay credentials missing',
        missing: missingCredentials,
      }, 500)
    }

    const supabase = createClient(supabaseUrl, serviceKey)

    const token = req.headers.get('Authorization')?.replace('Bearer ', '')
      .trim()
    if (!token) return json({ error: 'Unauthorized' }, 401)

    const { data: userData, error: userError } = await supabase.auth.getUser(
      token,
    )
    const user = userData?.user
    if (userError || !user) return json({ error: 'Invalid session' }, 401)

    const body = await readJsonBody(req)
    if (!body) return json({ error: 'Invalid body' }, 400)

    const orderId = body.order_id?.trim()
    const provider = normalizeProvider(body.provider ?? '')
    const customerPhone = body.customer_phone?.replace(/\s+/g, '').trim()
    const customerName = body.customer_name?.trim()

    if (!orderId || !body.provider || !customerPhone) {
      return json({
        error: 'Missing fields',
        required: ['order_id', 'provider', 'customer_phone'],
      }, 400)
    }

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('id, user_id, total, status')
      .eq('id', orderId)
      .single()

    if (orderError || !order) return json({ error: 'Order not found' }, 404)
    if (order.user_id !== user.id) return json({ error: 'Forbidden' }, 403)

    const amount = Number(order.total)
    const amountXof = Math.floor(amount)
    if (!Number.isFinite(amount) || amountXof < 200) {
      return json({ error: 'Invalid amount', min_amount: 200 }, 400)
    }

    const functionsUrl = functionsBaseUrl(req, supabaseUrl)
    const successUrl = env('GENIUSPAY_SUCCESS_URL')
      ? withReturnParams(env('GENIUSPAY_SUCCESS_URL')!, 'success', orderId)
      : paymentReturnUrl(functionsUrl, 'success', orderId)
    const errorUrl = env('GENIUSPAY_ERROR_URL')
      ? withReturnParams(env('GENIUSPAY_ERROR_URL')!, 'failed', orderId)
      : paymentReturnUrl(functionsUrl, 'failed', orderId)
    const forceProvider = env('GENIUSPAY_FORCE_PROVIDER') === 'true'

    const payload: Record<string, unknown> = {
      amount: amountXof,
      currency: 'XOF',
      description: `Commande Djassa #${orderId.slice(0, 8)}`,
      external_reference: orderId,
      success_url: successUrl,
      error_url: errorUrl,
      webhook_url: `${functionsUrl}/payment-webhook`,
      metadata: {
        order_id: orderId,
        user_id: user.id,
        provider,
      },
      customer: {
        phone: customerPhone,
        country: customerPhone.startsWith('+225') ? 'CI' : undefined,
        ...(customerName ? { name: customerName } : {}),
      },
    }

    // Hosted checkout is the default and returns checkout_url. Set
    // GENIUSPAY_FORCE_PROVIDER=true only if the merchant account accepts direct
    // provider routing for the selected operator.
    if (forceProvider) {
      Object.assign(payload, providerRouting(provider))
    }

    const headers: Record<string, string> = {
      'X-API-Key': geniusApiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Secret': geniusApiSecret,
    }

    const geniusResponse = await fetch(`${baseUrl}/payments`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    })

    const raw = await geniusResponse.text()
    let parsed: Record<string, unknown> = { raw }
    try {
      parsed = JSON.parse(raw)
    } catch {
      // Keep raw body for logs and controlled error payload below.
    }

    console.log('GeniusPay create payment', {
      url: `${baseUrl}/payments`,
      status: geniusResponse.status,
      body: parsed,
    })

    if (!geniusResponse.ok) {
      return json({
        error: 'GeniusPay payment creation failed',
        message: asRecord(parsed.error)?.message ??
          stringValue(parsed.message) ??
          stringValue(parsed.error) ??
          'Payment service unavailable',
        genius_status: geniusResponse.status,
      }, 502)
    }

    const data = asRecord(parsed.data) ?? parsed
    const checkoutUrl = pickString(data, [
      'checkout_url',
      'payment_url',
      'redirect_url',
      'url',
    ])
    const reference = pickString(data, [
      'reference',
      'transaction_id',
      'payment_reference',
      'id',
    ]) ?? `PAY-${Date.now()}`
    const providerPaymentId = pickString(data, [
      'id',
      'transaction_id',
      'payment_id',
    ])

    if (!checkoutUrl) {
      return json({
        error: 'Payment URL missing',
        message: 'GeniusPay did not return checkout_url or payment_url.',
        genius_status: geniusResponse.status,
      }, 502)
    }

    const richPayment = {
      order_id: orderId,
      user_id: user.id,
      provider,
      phone: customerPhone,
      reference,
      provider_payment_id: providerPaymentId,
      amount: amountXof,
      status: 'pending',
      checkout_url: checkoutUrl,
      webhook_url: `${functionsUrl}/payment-webhook`,
      metadata: {
        order_id: orderId,
        user_id: user.id,
        provider,
        customer_name: customerName ?? null,
        geniuspay: data,
      },
    }

    const minimalPayment = {
      order_id: orderId,
      user_id: user.id,
      provider,
      phone: customerPhone,
      reference,
      amount: amountXof,
      status: 'pending',
    }

    let { data: payment, error: paymentError } = await supabase
      .from('payments')
      .insert(richPayment)
      .select('id')
      .single()

    if (paymentError) {
      console.warn('Rich payment insert failed, retrying minimal insert', {
        code: paymentError.code,
        message: paymentError.message,
      })

      const fallback = await supabase
        .from('payments')
        .insert(minimalPayment)
        .select('id')
        .single()

      payment = fallback.data
      paymentError = fallback.error
    }

    if (paymentError) {
      return json({
        error: 'Payment created but database save failed',
        message: paymentError.message,
        checkout_url: checkoutUrl,
        reference,
        amount: amountXof,
        provider,
      }, 202)
    }

    return json({
      success: true,
      status: 'pending',
      checkout_url: checkoutUrl,
      payment_url: checkoutUrl,
      reference,
      payment_id: payment?.id,
      amount: amountXof,
      provider,
    })
  } catch (error) {
    return json({
      error: 'Server error',
      message: error instanceof Error ? error.message : String(error),
    }, 500)
  }
})
