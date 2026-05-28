# Supabase Edge Function: create-payment

Cette fonction garde la clé GeniusPay côté backend et crée un paiement depuis une commande existante.

## Secrets à configurer

```bash
supabase secrets set GENIUSPAY_API_KEY="pk_live_ou_sandbox_xxx"
# optionnel si l'URL change:
supabase secrets set GENIUSPAY_BASE_URL="https://geniuspay.ci/api/v1/merchant"
```

`SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` sont fournis automatiquement par Supabase aux Edge Functions.

## Déploiement

```bash
supabase functions deploy create-payment
```

L'app Flutter appelle ensuite `Supabase.instance.client.functions.invoke('create-payment')`.
