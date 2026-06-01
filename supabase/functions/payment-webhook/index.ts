// @ts-ignore: Deno types provided at runtime by Supabase Edge Functions
// @ts-ignore: esm.sh imports resolved at runtime
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-webhook-signature, x-webhook-timestamp, x-webhook-event',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type WebhookPayload = {
  id: string
  reference?: string
  transaction_id?: string
  status: string
  amount: number
  currency: string
  metadata?: Record<string, unknown>
  created_at?: string
  event?: string
}

/**
 * Vérifie la signature HMAC SHA-256 du webhook GeniusPay
 * Format attendu : signature = hex(HMAC-SHA256(secret, "${timestamp}.${payload}"))
 */
async function verifyWebhookSignature(
  payload: string,
  signature: string,
  timestamp: string,
  secret: string
): Promise<boolean> {
  try {
    // Message signé : timestamp.payload (exactement comme GeniusPay le génère)
    const message = `${timestamp}.${payload}`
    
    const encoder = new TextEncoder()
    const keyData = encoder.encode(secret)
    const messageData = encoder.encode(message)
    
    // Import de la clé pour HMAC-SHA256
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign', 'verify']
    )
    
    // Calcul de la signature attendue
    const signatureBuffer = await crypto.subtle.sign(
      'HMAC',
      cryptoKey,
      messageData
    )
    
    // Conversion en hexadécimal (format attendu par GeniusPay)
    const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')
    
    // Comparaison constante pour éviter les attaques par timing
    if (signature.length !== expectedSignature.length) return false
    let result = 0
    for (let i = 0; i < signature.length; i++) {
      result |= signature.charCodeAt(i) ^ expectedSignature.charCodeAt(i)
    }
    return result === 0
  } catch (error) {
    console.error('❌ Erreur vérification signature:', error)
    return false
  }
}

/**
 * Vérifie que le timestamp n'est pas trop ancien (±5 minutes)
 */
function isTimestampValid(timestamp: string, windowMinutes = 5): boolean {
  const now = Math.floor(Date.now() / 1000)
  const webhookTime = parseInt(timestamp, 10)
  
  if (isNaN(webhookTime)) return false
  const diff = Math.abs(now - webhookTime)
  return diff <= windowMinutes * 60
}

/**
 * Vérifie l'idempotence via la table webhook_logs
 */
async function isEventAlreadyProcessed(
  supabase: any,
  eventId: string
): Promise<boolean> {
  const { data, error } = await supabase
    .from('webhook_logs')
    .select('id')
    .eq('event_id', eventId)
    .maybeSingle()
  
  if (error) {
    console.warn('⚠️ Erreur vérification idempotence:', error)
    return false // En cas d'erreur, on traite quand même pour éviter de perdre un paiement
  }
  
  return data !== null
}

async function markEventAsProcessed(
  supabase: any,
  eventId: string,
  payload: Record<string, unknown>
) {
  try {
    await supabase.from('webhook_logs').insert({
      event_id: eventId,
      event_type: payload['event'] ?? 'unknown',
      processed_at: new Date().toISOString(),
      payload_summary: {
        reference: payload['reference'],
        status: payload['status'],
        amount: payload['amount'],
      },
    })
  } catch (error) {
    console.warn('⚠️ Échec enregistrement webhook_logs:', error)
    // Non bloquant : mieux vaut traiter le paiement que de crasher pour un log
  }
}

function paymentStatusCandidates(status: string | undefined): string[] {
  switch ((status ?? '').toLowerCase()) {
    case 'success':
    case 'successful':
    case 'approved':
    case 'validated':
    case 'complete':
    case 'completed':
    case 'paid':
      return ['completed', 'paid']
    case 'failed':
    case 'error':
    case 'declined':
      return ['failed']
    case 'cancelled':
    case 'canceled':
      return ['cancelled']
    case 'processing':
    case 'initiated':
      return ['processing', 'pending']
    case 'refunded':
    case 'partially_refunded':
      return ['refunded']
    default:
      return ['pending']
  }
}

async function updatePaymentStatus(
  supabase: any,
  reference: string,
  statuses: string[],
  eventLabel: string,
  payload: WebhookPayload
): Promise<{ data: any; error: any; status: string }> {
  let lastError: any = null

  for (const status of statuses) {
    const richResult = await supabase
      .from('payments')
      .update({
        status,
        status_message: `Webhook ${eventLabel}: ${payload.status}`,
        updated_at: new Date().toISOString(),
        metadata: {
          ...(payload.metadata || {}),
          webhook_received_at: new Date().toISOString(),
          webhook_event_id: payload.id,
          webhook_signature_verified: true,
        },
      })
      .eq('reference', reference)
      .select()
      .maybeSingle()

    if (!richResult.error && richResult.data) {
      return { data: richResult.data, error: null, status }
    }

    lastError = richResult.error
    console.warn('Rich webhook update failed, retrying minimal update:', {
      status,
      code: richResult.error?.code,
      message: richResult.error?.message ?? 'Payment reference not found',
    })

    const minimalResult = await supabase
      .from('payments')
      .update({
        status,
        updated_at: new Date().toISOString(),
      })
      .eq('reference', reference)
      .select()
      .maybeSingle()

    if (!minimalResult.error && minimalResult.data) {
      return { data: minimalResult.data, error: null, status }
    }

    lastError = minimalResult.error
  }

  return {
    data: null,
    error: lastError ?? { message: 'Payment reference not found' },
    status: statuses[0] ?? 'pending',
  }
}

// @ts-ignore: Deno.serve is available at runtime in Supabase Edge Functions
Deno.serve(async (req: Request) => {
  // 🔁 Gestion CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // 🔒 Seul POST est autorisé
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { 
      status: 405, 
      headers: corsHeaders 
    })
  }

  try {
    // ⚙️ Configuration depuis les variables d'environnement
    // @ts-ignore
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    // @ts-ignore
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    // @ts-ignore
    const geniusWebhookSecret = Deno.env.get('GENIUSPAY_WEBHOOK_SECRET')
    
    if (!supabaseUrl || !serviceRoleKey) {
      console.error('❌ Configuration Supabase manquante')
      return new Response('Configuration error', { 
        status: 500,
        headers: corsHeaders 
      })
    }
    
    // Le secret webhook est DIFFÉRENT de la clé API
    // @ts-ignore
    const webhookSecret = geniusWebhookSecret ?? Deno.env.get('GENIUSPAY_API_KEY')
    if (!webhookSecret) {
      console.error('❌ Secret webhook manquant dans les variables d\'environnement')
      return new Response('Webhook secret not configured', { 
        status: 500,
        headers: corsHeaders 
      })
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    // 🔐 Vérification des headers de sécurité
    const signature = req.headers.get('x-webhook-signature')
    const timestamp = req.headers.get('x-webhook-timestamp')
    const eventType = req.headers.get('x-webhook-event')
    
    if (!signature || !timestamp) {
      console.warn('⚠️ Headers de signature manquants:', { signature: !!signature, timestamp: !!timestamp })
      return new Response('Missing security headers', { 
        status: 400, 
        headers: corsHeaders 
      })
    }

    // Vérification du timestamp (anti-replay)
    if (!isTimestampValid(timestamp)) {
      console.warn('⚠️ Timestamp invalide ou trop ancien:', timestamp)
      return new Response('Invalid timestamp', { 
        status: 400, 
        headers: corsHeaders 
      })
    }

    // 📥 Lecture du payload RAW (nécessaire pour la vérification HMAC)
    const rawPayload = await req.text()
    
    // 🔐 Vérification de la signature HMAC-SHA256
    const isValid = await verifyWebhookSignature(
      rawPayload,
      signature,
      timestamp,
      webhookSecret
    )
    
    if (!isValid) {
      console.error('❌ Signature HMAC invalide - Rejet du webhook')
      return new Response('Invalid signature', { 
        status: 401, 
        headers: corsHeaders 
      })
    }
    
    console.log('✅ Signature vérifiée avec succès')

    // 📦 Parsing du JSON
    let payload: WebhookPayload
    try {
      payload = JSON.parse(rawPayload)
    } catch (parseError) {
      console.error('❌ Échec parsing JSON:', parseError)
      return new Response('Invalid JSON payload', { 
        status: 400, 
        headers: corsHeaders 
      })
    }

    console.log('📥 Webhook reçu:', {
      event: eventType ?? payload.event,
      id: payload.id,
      reference: payload.reference,
      status: payload.status,
      amount: payload.amount,
    })

    // 🔁 Idempotence : éviter de traiter 2x le même événement
    if (await isEventAlreadyProcessed(supabaseAdmin, payload.id)) {
      console.log('⚠️ Événement déjà traité (idempotence):', payload.id)
      return new Response(JSON.stringify({ received: true, duplicate: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Try statuses compatible with both payment schema variants.
    const statusCandidates = paymentStatusCandidates(payload.status)
    const reference = payload.reference ?? payload.transaction_id

    if (!reference) {
      console.error('❌ Reference manquante dans le payload')
      return new Response(JSON.stringify({ error: 'Missing reference' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 🗄️ Mise à jour du paiement dans la base
    const {
      data: updatedPayment,
      error,
      status: persistedStatus,
    } = await updatePaymentStatus(
      supabaseAdmin,
      reference,
      statusCandidates,
      eventType ?? payload.event ?? 'unknown',
      payload
    )

    if (error) {
      console.error('❌ Échec mise à jour paiement:', error)
      // On retourne 200 pour éviter que GeniusPay retry indéfiniment
      return new Response(JSON.stringify({ 
        received: true, 
        error: 'Database update failed',
        reference 
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (persistedStatus === 'completed' || persistedStatus === 'paid') {
      const metadata = payload.metadata ?? {}
      const orderId = typeof metadata['order_id'] === 'string'
        ? metadata['order_id']
        : updatedPayment?.order_id

      if (orderId) {
        const { error: orderUpdateError } = await supabaseAdmin
          .from('orders')
          .update({
            status: 'paid',
            updated_at: new Date().toISOString(),
          })
          .eq('id', orderId)
          .in('status', ['pending_payment', 'pending', 'confirmed'])

        if (orderUpdateError) {
          console.warn('Order status update skipped:', orderUpdateError)
        }
      }
    }

    console.log('✅ Paiement mis à jour:', { 
      reference, 
      newStatus: persistedStatus,
      payment_id: updatedPayment?.id 
    })

    // 📝 Marquer l'événement comme traité (idempotence)
    await markEventAsProcessed(supabaseAdmin, payload.id, {
      event: eventType ?? payload.event,
      reference: payload.reference,
      status: payload.status,
      amount: payload.amount,
    })

    // 🎉 Réponse de succès (GeniusPay attend < 5 secondes)
    return new Response(JSON.stringify({ 
      received: true, 
      reference: reference,
      status: persistedStatus,
      event_id: payload.id,
      processed_at: new Date().toISOString(),
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error: any) {
    console.error('💥 Exception globale webhook:', {
      name: error?.name ?? 'Unknown',
      message: error?.message ?? String(error),
      stack: error?.stack,
    })
    
    // Toujours retourner 200 pour éviter les retries infinis de GeniusPay
    // L'erreur est loggée pour investigation ultérieure
    return new Response(JSON.stringify({ 
      error: 'Internal error',
      message: error?.message ?? 'Unknown error'
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
