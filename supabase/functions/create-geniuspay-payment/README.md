# Supabase Edge Function: create-geniuspay-payment

Creates a GeniusPay payment from an existing order and returns a URL that the
Flutter app can open in its WebView.

## Required secrets

```bash
supabase secrets set GENIUSPAY_API_KEY="pk_live_or_pk_sandbox_xxx"
supabase secrets set GENIUSPAY_API_SECRET="sk_live_or_sk_sandbox_xxx"
```

Accepted aliases are `GENIUSPAY_PUBLIC_KEY` for the public key and
`GENIUSPAY_SECRET_KEY` / `GENIUSPAY_SECRET` for the secret key.

Optional:

```bash
supabase secrets set GENIUSPAY_BASE_URL="https://geniuspay.ci/api/v1/merchant"
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase at
runtime.

## Deploy

```bash
supabase functions deploy create-geniuspay-payment
supabase functions deploy payment-return
```
