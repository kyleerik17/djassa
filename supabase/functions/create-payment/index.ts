import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type PaymentRequest = {
  order_id?: string
  amount?: number
  provider?: string
  customer_phone?: string
  customer_name?: string
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Méthode non autorisée' }, 405)
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const geniusApiKey = Deno.env.get('GENIUSPAY_API_KEY')
    const geniusBaseUrl = Deno.env.get('GENIUSPAY_BASE_URL') ??
      'https://geniuspay.ci/api/v1/merchant'

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: 'Configuration Supabase manquante' }, 500)
    }

    if (!geniusApiKey) {
      return jsonResponse({ error: 'GENIUSPAY_API_KEY manquante côté backend' }, 500)
    }

    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.replace('Bearer ', '').trim()
    if (!token) {
      return jsonResponse({ error: 'Utilisateur non connecté' }, 401)
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)
    const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(token)
    if (authError || !authData.user) {
      return jsonResponse({ error: 'Session invalide' }, 401)
    }

    const body = await req.json() as PaymentRequest
    const orderId = body.order_id
    const provider = body.provider
    const customerPhone = body.customer_phone
    const customerName = body.customer_name

    if (!orderId || !provider || !customerPhone) {
      return jsonResponse({
        error: 'order_id, provider et customer_phone sont obligatoires',
      }, 400)
    }

    const { data: order, error: orderError } = await supabaseAdmin
      .from('orders')
      .select('id, user_id, total')
      .eq('id', orderId)
      .single()

    if (orderError || !order) {
      return jsonResponse({ error: 'Commande introuvable' }, 404)
    }

    if (order.user_id !== authData.user.id) {
      return jsonResponse({ error: 'Commande non autorisée' }, 403)
    }

    // Sécurité: le montant utilisé vient de la commande en base, pas du client.
    const amount = Number(order.total)
    if (!Number.isFinite(amount) || amount <= 0) {
      return jsonResponse({ error: 'Montant de commande invalide' }, 400)
    }

    const geniusResponse = await fetch(`${geniusBaseUrl}/payments`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${geniusApiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        amount,
        description: 'Commande Djassa',
        metadata: { order_id: orderId, user_id: authData.user.id },
        customer: {
          ...(customerName ? { name: customerName } : {}),
          phone: customerPhone,
        },
      }),
    })

    const geniusBodyText = await geniusResponse.text()
    let geniusBody: Record<string, unknown>
    try {
      geniusBody = JSON.parse(geniusBodyText)
    } catch (_) {
      geniusBody = { raw: geniusBodyText }
    }

    if (!geniusResponse.ok) {
      return jsonResponse({
        error: 'Erreur GeniusPay',
        status: geniusResponse.status,
        details: geniusBody,
      }, 502)
    }

    const data = (geniusBody.data ?? geniusBody) as Record<string, unknown>
    const checkoutUrl = typeof data.checkout_url === 'string' ? data.checkout_url : ''
    const reference = typeof data.reference === 'string'
      ? data.reference
      : `PAY-${Date.now()}`

    if (!checkoutUrl) {
      return jsonResponse({
        error: 'checkout_url manquante dans la réponse GeniusPay',
        details: geniusBody,
      }, 502)
    }

    const { error: paymentError } = await supabaseAdmin.from('payments').insert({
      order_id: orderId,
      user_id: authData.user.id,
      provider,
      phone: customerPhone,
      reference,
      amount,
      status: 'pending',
    })

    if (paymentError) {
      return jsonResponse({
        error: 'Paiement créé mais sauvegarde Supabase impossible',
        details: paymentError.message,
      }, 500)
    }

    return jsonResponse({
      checkout_url: checkoutUrl,
      reference,
    })
  } catch (error) {
    return jsonResponse({
      error: error instanceof Error ? error.message : 'Erreur inconnue',
    }, 500)
  }
})
