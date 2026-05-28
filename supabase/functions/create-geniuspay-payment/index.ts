// @ts-ignore: Deno types provided at runtime by Supabase Edge Functions
// @ts-ignore: esm.sh imports resolved at runtime
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type PaymentRequest = {
  order_id?: string
  provider?: string
  customer_phone?: string
  customer_name?: string
}

type PaymentResponse = {
  checkout_url: string
  reference: string
  payment_id?: string
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

// @ts-ignore: Deno.serve is available at runtime in Supabase Edge Functions
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Méthode non autorisée' }, 405)
  }

  try {
    // 🔐 1. Configuration environnementale
    // @ts-ignore
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    // @ts-ignore
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    // @ts-ignore
    const geniusApiKey = Deno.env.get('GENIUSPAY_API_KEY')
    // @ts-ignore
    const geniusBaseUrl = Deno.env.get('GENIUSPAY_BASE_URL') ?? 'https://geniuspay.ci/api/v1/merchant'
    // @ts-ignore
    const functionsUrl = Deno.env.get('SUPABASE_FUNCTION_URL') ?? ''

    if (!supabaseUrl || !serviceRoleKey) {
      console.error('❌ Configuration Supabase manquante')
      return jsonResponse({ error: 'Configuration serveur invalide' }, 500)
    }

    if (!geniusApiKey) {
      console.error('❌ GENIUSPAY_API_KEY manquante')
      return jsonResponse({ error: 'Configuration paiement invalide' }, 500)
    }

    // 🔐 2. Vérification authentification
    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.replace('Bearer ', '').trim()
    
    if (!token) {
      return jsonResponse({ error: 'Utilisateur non authentifié' }, 401)
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)
    
    const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(token)
    if (authError || !authData?.user) {
      console.warn('⚠️ Session invalide:', authError?.message)
      return jsonResponse({ error: 'Session invalide ou expirée' }, 401)
    }

    const userId = authData.user.id
    console.log('✅ Utilisateur authentifié:', userId)

    // 📥 3. Parsing inputs
    let body: PaymentRequest
    try {
      body = await (req.json() as Promise<PaymentRequest>)
    } catch {
      return jsonResponse({ error: 'Corps de la requête invalide' }, 400)
    }

    const { order_id, provider, customer_phone, customer_name } = body

    if (!order_id || !provider || !customer_phone) {
      return jsonResponse({
        error: 'Champs requis manquants',
        required: ['order_id', 'provider', 'customer_phone'],
      }, 400)
    }

    // 🔍 4. Vérification commande
    const { data: order, error: orderError } = await supabaseAdmin
      .from('orders')
      .select('id, user_id, total, status')
      .eq('id', order_id)
      .single()

    if (orderError || !order) {
      console.warn('⚠️ Commande introuvable:', order_id)
      return jsonResponse({ error: 'Commande introuvable' }, 404)
    }

    if (order.user_id !== userId) {
      console.warn('⚠️ Accès refusé:', { order_id, userId })
      return jsonResponse({ error: 'Accès refusé à cette commande' }, 403)
    }

    if (order.status !== 'pending' && order.status !== 'confirmed' && order.status !== 'pending_payment') {
      return jsonResponse({ 
        error: 'Cette commande ne peut plus être payée',
        current_status: order.status 
      }, 400)
    }

    // 🛡️ 5. Montant sécurisé depuis DB
    const amount = Number(order.total)
    if (!Number.isFinite(amount) || amount <= 0) {
      return jsonResponse({ error: 'Montant de commande invalide' }, 400)
    }

    console.log('📦 Création paiement:', { order_id, amount, provider })

    // 💳 6. Appel API GeniusPay
    const geniusPayload = {
      amount: Math.floor(amount),
      currency: 'XOF',
      description: `Commande Djassa #${order_id.slice(0, 8)}`,
      metadata: {
        order_id: order_id,
        user_id: userId,
        platform: 'flutter',
      },
      customer: {
        ...(customer_name ? { name: customer_name } : {}),
        phone: customer_phone,
      },
      webhook_url: `${functionsUrl}/payment-webhook`,
      return_url: 'djassaapp://payment-callback',
    }

    const geniusResponse = await fetch(`${geniusBaseUrl}/payments`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${geniusApiKey}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify(geniusPayload),
    })

    const geniusBodyText = await geniusResponse.text()
    let geniusBody: Record<string, unknown>
    
    try {
      geniusBody = JSON.parse(geniusBodyText)
    } catch {
      geniusBody = { raw: geniusBodyText }
    }

    if (!geniusResponse.ok) {
      console.error('❌ Erreur GeniusPay:', { status: geniusResponse.status, body: geniusBody })
      return jsonResponse({
        error: 'Échec de la création du paiement',
        status: geniusResponse.status,
        details: geniusBody.message || geniusBody.error || 'Erreur GeniusPay',
      }, 502)
    }

    // 🎯 7. Extraction réponse (✅ FIX: notation par crochets)
    const responseData = (geniusBody.data ?? geniusBody) as Record<string, unknown>
    
    // ✅ Accès sécurisé aux propriétés avec notation [key]
    const checkoutUrl = typeof responseData['checkout_url'] === 'string' 
      ? responseData['checkout_url'] as string
      : ''
    
    const reference = typeof responseData['reference'] === 'string'
      ? responseData['reference'] as string
      : typeof responseData['transaction_id'] === 'string'
        ? responseData['transaction_id'] as string
        : `PAY-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`

    const providerPaymentId = typeof responseData['id'] === 'string'
      ? responseData['id'] as string
      : typeof responseData['transaction_id'] === 'string'
        ? responseData['transaction_id'] as string
        : null

    if (!checkoutUrl) {
      console.error('❌ checkout_url manquante:', geniusBody)
      return jsonResponse({
        error: 'Configuration GeniusPay invalide',
        details: 'Aucune URL de paiement retournée',
      }, 502)
    }

    // 🗄️ 8. Enregistrement paiement
    const { data: payment, error: paymentError } = await supabaseAdmin
      .from('payments')
      .insert({
        order_id: order_id,
        user_id: userId,
        provider: provider,
        phone: customer_phone,
        reference: reference,
        provider_payment_id: providerPaymentId,
        amount: amount,
        status: 'pending',
        checkout_url: checkoutUrl,
        webhook_url: `${functionsUrl}/payment-webhook`,
        metadata: {
          order_id: order_id,
          user_id: userId,
          provider: provider,
          customer_name: customer_name,
          created_via: 'edge_function',
        },
      })
      .select('id')
      .single()

    if (paymentError) {
      console.error('❌ Échec sauvegarde:', paymentError)
      return jsonResponse({
        warning: 'Paiement créé mais enregistrement partiel',
        checkout_url: checkoutUrl,
        reference: reference,
        error: paymentError.message,
      }, 202)
    }

    console.log('✅ Paiement enregistré:', { reference })

    // 🎉 9. Réponse finale
    return jsonResponse({
      checkout_url: checkoutUrl,
      reference: reference,
      payment_id: payment?.id,
      amount: amount,
      provider: provider,
    } as PaymentResponse & { amount: number; provider: string })

  } catch (error: unknown) {
    console.error('💥 Exception Edge Function:', {
      name: error instanceof Error ? error.name : 'Unknown',
      message: error instanceof Error ? error.message : String(error),
    })
    
    return jsonResponse({
      error: 'Erreur serveur lors de la création du paiement',
      message: error instanceof Error ? error.message : 'Erreur inconnue',
    }, 500)
  }
})