// /**
//  * Tests de sécurité automatisés pour payment-return
//  * Exécution: deno run --allow-net tests/payment-return.security.test.ts
//  * 
//  * ⚠️ Remplacez BASE_URL par l'URL de votre fonction déployée ou locale
//  */

// const BASE_URL = Deno.env.get("PAYMENT_RETURN_URL") ??
//   "http://localhost:54321/functions/v1/payment-return";

// const ALLOWED_ORIGIN = "https://djassa.app";
// const MALICIOUS_ORIGIN = "https://evil-attacker.com";

// // ─── Utilitaires ────────────────────────────────────────────────

// let passed = 0;
// let failed = 0;
// const results: { name: string; ok: boolean; detail?: string }[] = [];

// async function test(
//   name: string,
//   fn: () => Promise<boolean> | boolean,
// ): Promise<void> {
//   try {
//     const ok = await fn();
//     if (ok) {
//       passed++;
//       console.log(`  ✅ ${name}`);
//     } else {
//       failed++;
//       console.log(`  ❌ ${name}`);
//     }
//     results.push({ name, ok });
//   } catch (e) {
//     failed++;
//     const detail = e instanceof Error ? e.message : String(e);
//     console.log(`  ❌ ${name} — ERREUR: ${detail}`);
//     results.push({ name, ok: false, detail });
//   }
// }

// function assert(condition: boolean, message: string): asserts condition {
//   if (!condition) throw new Error(message);
// }

// async function fetchReturn(
//   params?: Record<string, string>,
//   options?: { method?: string; origin?: string },
// ): Promise<{ status: number; headers: Headers; body: string }> {
//   const url = new URL(BASE_URL);
//   if (params) {
//     Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));
//   }

//   const headers = new Headers();
//   if (options?.origin) headers.set("Origin", options.origin);

//   const res = await fetch(url.toString(), {
//     method: options?.method ?? "GET",
//     headers,
//     redirect: "manual",
//   });

//   return {
//     status: res.status,
//     headers: res.headers,
//     body: await res.text(),
//   };
// }

// // ─── 1. VALIDATION DES ENTRÉES (Zod .strict()) ────────────────

// console.log("\n🔒 1. Validation des entrées");

// await test("Requête valide → 200 + page HTML", async () => {
//   const r = await fetchReturn({ status: "completed", reference: "REF_abc-123" });
//   return r.status === 200 && r.body.includes("<!doctype html>");
// });

// await test("Paramètre inconnu (__proto__) → rejeté (page pending)", async () => {
//   const r = await fetchReturn({
//     status: "completed",
//     "__proto__": "polluted",
//   } as Record<string, string>);
//   // .strict() rejette → page pending retournée
//   return r.status === 200 && r.body.includes("Paiement non confirme");
// });

// await test("Paramètre inconnu (constructor) → rejeté", async () => {
//   const r = await fetchReturn({
//     status: "pending",
//     "constructor": "prototype",
//   } as Record<string, string>);
//   return r.status === 200 && r.body.includes("Paiement non confirme");
// });

// await test("XSS dans status → rejeté par regex", async () => {
//   const r = await fetchReturn({ status: "<script>alert(1)</script>" });
//   // Regex STATUS_PATTERN rejette → fallback 'pending'
//   return r.status === 200 &&
//     !r.body.includes("<script>") &&
//     r.body.includes("Paiement non confirme");
// });

// await test("XSS dans reference → échappé dans la réponse", async () => {
//   // Reference avec caractères spéciaux rejetée par regex REFERENCE_PATTERN
//   const r = await fetchReturn({ reference: '<img src=x onerror=alert(1)>' });
//   return r.status === 200 && !r.body.includes("<img");
// });

// await test("Reference trop longue (>64 chars) → rejetée", async () => {
//   const longRef = "A".repeat(65);
//   const r = await fetchReturn({ status: "pending", reference: longRef });
//   return r.status === 200 && r.body.includes("Paiement non confirme");
// });

// await test("UUID invalide dans order_id → rejeté", async () => {
//   const r = await fetchReturn({ order_id: "not-a-valid-uuid" });
//   return r.status === 200 && r.body.includes("Paiement non confirme");
// });

// await test("UUID valide accepté", async () => {
//   const uuid = "550e8400-e29b-41d4-a716-446655440000";
//   const r = await fetchReturn({ order_id: uuid, status: "pending" });
//   return r.status === 200;
// });

// await test("Status vide → fallback pending sécurisé", async () => {
//   const r = await fetchReturn({});
//   return r.status === 200 && r.body.includes("Paiement non confirme");
// });

// await test("Injection SQL dans reference → rejetée par regex", async () => {
//   const r = await fetchReturn({ reference: "'; DROP TABLE payments;--" });
//   // Regex REFERENCE_PATTERN rejette les caractères spéciaux
//   return r.status === 200 && r.body.includes("Paiement non confirme");
// });

// // ─── 2. CORS ───────────────────────────────────────────────────

// console.log("\n🌐 2. Configuration CORS");

// await test("Origin autorisé → reflété dans ACAO", async () => {
//   const r = await fetchReturn({ status: "pending" }, { origin: ALLOWED_ORIGIN });
//   const acao = r.headers.get("Access-Control-Allow-Origin");
//   return acao === ALLOWED_ORIGIN;
// });

// await test("Origin malveillant → PAS reflété (origin par défaut)", async () => {
//   const r = await fetchReturn({ status: "pending" }, { origin: MALICIOUS_ORIGIN });
//   const acao = r.headers.get("Access-Control-Allow-Origin");
//   return acao !== MALICIOUS_ORIGIN && acao !== "*";
// });

// await test("Pas d'Origin → origin par défaut sécurisé", async () => {
//   const r = await fetchReturn({ status: "pending" });
//   const acao = r.headers.get("Access-Control-Allow-Origin");
//   return acao !== "*" && acao !== null;
// });

// await test("OPTIONS preflight → 200 + headers CORS", async () => {
//   const r = await fetchReturn(undefined, {
//     method: "OPTIONS",
//     origin: ALLOWED_ORIGIN,
//   });
//   return r.status === 200 &&
//     r.headers.get("Access-Control-Allow-Methods")?.includes("GET") === true;
// });

// // ─── 3. MÉTHODES HTTP ─────────────────────────────────────────

// console.log("\n🚫 3. Méthodes HTTP non autorisées");

// for (const method of ["POST", "PUT", "DELETE", "PATCH"]) {
//   await test(`${method} → 405 Method Not Allowed`, async () => {
//     const r = await fetchReturn({ status: "pending" }, { method });
//     return r.status === 405;
//   });
// }

// // ─── 4. HEADERS DE SÉCURITÉ ───────────────────────────────────

// console.log("\n🛡️ 4. Headers de sécurité");

// await test("Content-Type correct → text/html; charset=utf-8", async () => {
//   const r = await fetchReturn({ status: "pending" });
//   return r.headers.get("Content-Type") === "text/html; charset=utf-8";
// });

// await test("Réponse ne contient jamais service_role key", async () => {
//   const r = await fetchReturn({ status: "completed", reference: "REF_test" });
//   return !r.body.includes("eyJ") && !r.body.includes("service_role");
// });

// await test("Réponse ne contient jamais stack trace", async () => {
//   const r = await fetchReturn({ status: "pending" });
//   return !r.body.includes("stack") &&
//     !r.body.includes("at ") &&
//     !r.body.includes("Error:");
// });

// // ─── 5. RÉSILIENCE & EDGE CASES ──────────────────────────────

// console.log("\n⚡ 5. Résilience");

// await test("Tous les paramètres à la fois → pas de crash", async () => {
//   const r = await fetchReturn({
//     status: "completed",
//     payment_status: "paid",
//     transaction_status: "success",
//     state: "validated",
//     order_id: "550e8400-e29b-41d4-a716-446655440000",
//     orderId: "660e8400-e29b-41d4-a716-446655440001",
//     reference: "REF_multi-test",
//     transaction_id: "TXN_001",
//     payment_reference: "PAY_REF_001",
//     payment_id: "PAY_ID_001",
//   });
//   return r.status === 200 && r.body.includes("<!doctype html>");
// });

// await test("Valeurs avec espaces → trimmées correctement", async () => {
//   const r = await fetchReturn({ status: "  completed  ", reference: "  REF_trim  " });
//   return r.status === 200;
// });

// await test("Paramètres dupliqués → gérés sans erreur", async () => {
//   const url = new URL(BASE_URL);
//   url.searchParams.append("status", "completed");
//   url.searchParams.append("status", "failed");
//   const res = await fetch(url.toString());
//   return res.status === 200;
// });

// // ─── RAPPORT FINAL ────────────────────────────────────────────

// console.log("\n" + "═".repeat(60));
// console.log(`📊 RÉSULTATS: ${passed}✅ / ${failed}❌ / ${passed + failed} total`);
// console.log("═".repeat(60));

// if (failed > 0) {
//   console.log("\n❌ TESTS ÉCHOUÉS:");
//   results.filter((r) => !r.ok).forEach((r) => {
//     console.log(`   • ${r.name}${r.detail ? ` (${r.detail})` : ""}`);
//   });
//   Deno.exit(1);
// } else {
//   console.log("\n🎉 Tous les tests de sécurité passent !");
//   Deno.exit(0);
// }