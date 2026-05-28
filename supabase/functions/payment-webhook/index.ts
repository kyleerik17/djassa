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
 */
async function verifyWebhookSignature(
  payload: string,
  signature: string,
  timestamp: string,
  secret: string
): Promise<boolean> {
  try {
    const message = `${timestamp}.${payload}`
    
    const encoder = new TextEncoder()
    const keyData = encoder.encode(secret)
    const messageData = encoder.encode(message)
    
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign', 'verify']
    )
    
    const signatureBuffer = await crypto.subtle.sign(
      'HMAC',
      cryptoKey,
      messageData
    )
    
    const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')
    
    return signature === expectedSignature
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
  const { data } = await supabase
    .from('webhook_logs')
    .select('id')
    .eq('event_id', eventId)
    .maybeSingle()
  
  return data !== null
}

async function markEventAsProcessed(
  supabase: any,
  eventId: string,
  payload: Record<string, unknown>
) {
  await supabase.from('webhook_logs').insert({
    event_id: eventId,
    event_type: payload['event'] ?? 'unknown',
    processed_at: new Date().toISOString(),
    payload_summary: {
      reference: payload['reference'],
      status: payload['status'],
      amount: payload['amount'],
    },
  }).select()
}

// @ts-ignore: Deno.serve is available at runtime in Supabase Edge Functions
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  try {
    // 🔐 Configuration - @ts-ignore for Deno.env
    // @ts-ignore
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    // @ts-ignore
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    // @ts-ignore
    const geniusWebhookSecret = Deno.env.get('GENIUSPAY_WEBHOOK_SECRET')
    
    if (!supabaseUrl || !serviceRoleKey) {
      console.error('❌ Config Supabase manquante')
      return new Response('Configuration error', { status: 500 })
    }
    
    // @ts-ignore
    const webhookSecret = geniusWebhookSecret ?? Deno.env.get('GENIUSPAY_API_KEY')
    if (!webhookSecret) {
      console.error('❌ Secret webhook manquant')
      return new Response('Webhook secret not configured', { status: 500 })
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    // 🔐 Headers de sécurité
    const signature = req.headers.get('x-webhook-signature')
    const timestamp = req.headers.get('x-webhook-timestamp')
    const eventType = req.headers.get('x-webhook-event')
    
    if (!signature || !timestamp) {
      console.warn('⚠️ Headers de signature manquants')
      return new Response('Missing security headers', { 
        status: 400, 
        headers: corsHeaders 
      })
    }

    if (!isTimestampValid(timestamp)) {
      console.warn('⚠️ Timestamp invalide:', timestamp)
      return new Response('Invalid timestamp', { 
        status: 400, 
        headers: corsHeaders 
      })
    }

    // 📥 Payload RAW pour signature
    const rawPayload = await req.text()
    
    // 🔐 Vérification signature HMAC
    const isValid = await verifyWebhookSignature(
      rawPayload,
      signature,
      timestamp,
      webhookSecret
    )
    
    if (!isValid) {
      console.error('❌ Signature invalide')
      return new Response('Invalid signature', { 
        status: 401, 
        headers: corsHeaders 
      })
    }
    
    console.log('✅ Signature vérifiée')

    // 📦 Parsing JSON
    let payload: WebhookPayload
    try {
      payload = JSON.parse(rawPayload)
    } catch {
      return new Response('Invalid JSON payload', { 
        status: 400, 
        headers: corsHeaders 
      })
    }

    console.log('📥 Webhook:', {
      event: eventType ?? payload.event,
      id: payload.id,
      reference: payload.reference,
      status: payload.status,
    })

    // 🔁 Idempotence
    if (await isEventAlreadyProcessed(supabaseAdmin, payload.id)) {
      console.log('⚠️ Déjà traité:', payload.id)
      return new Response(JSON.stringify({ received: true, duplicate: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 🔄 Mapping statuts
    const statusMap: Record<string, string> = {
      'success': 'completed',
      'completed': 'completed', 
      'paid': 'completed',
      'failed': 'failed',
      'error': 'failed',
      'cancelled': 'cancelled',
      'pending': 'pending',
      'processing': 'processing',
      'refunded': 'refunded',
      'initiated': 'processing',
    }

    const newStatus = statusMap[payload.status?.toLowerCase()] ?? 'pending'
    const reference = payload.reference ?? payload.transaction_id

    if (!reference) {
      return new Response(JSON.stringify({ error: 'Missing reference' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 🗄️ Mise à jour paiement
    const { error } = await supabaseAdmin
      .from('payments')
      .update({
        status: newStatus,
        status_message: `Webhook ${eventType ?? payload.event}: ${payload.status}`,
        updated_at: new Date().toISOString(),
        metadata: {
          ...(payload.metadata || {}),
          webhook_received_at: new Date().toISOString(),
          webhook_event_id: payload.id,
        },
      })
      .eq('reference', reference)

    if (error) {
      console.error('❌ Échec update:', error)
      return new Response(JSON.stringify({ received: true, error: 'Update failed' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('✅ Paiement mis à jour:', { reference, newStatus })

    // 📝 Idempotence : marquer comme traité
    await markEventAsProcessed(supabaseAdmin, payload.id, {
      event: eventType ?? payload.event,
      reference: payload.reference,
      status: payload.status,
      amount: payload.amount,
    })

    // 🎉 Réponse rapide (< 5s requis)
    return new Response(JSON.stringify({ 
      received: true, 
      reference: reference,
      status: newStatus,
      event_id: payload.id,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error: any) {
    console.error('💥 Exception Webhook:', {
      name: error?.name ?? 'Unknown',
      message: error?.message ?? String(error),
    })
    
    // Toujours 200 pour éviter retries infinis
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})