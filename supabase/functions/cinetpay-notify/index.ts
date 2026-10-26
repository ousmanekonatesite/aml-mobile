import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const form = await req.formData();
    const transactionId = String(form.get('cpm_trans_id') ?? '');
    if (!transactionId) return Response.json({ ok: false, error: 'MISSING_TRANSACTION' }, { status: 400 });

    // CinetPay recommande de vérifier le statut via son API plutôt que de faire confiance
    // au seul contenu de la notification.
    const check = await fetch('https://api-checkout.cinetpay.com/v2/payment/check', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        transaction_id: transactionId,
        site_id: Deno.env.get('CINETPAY_SITE_ID'),
        apikey: Deno.env.get('CINETPAY_APIKEY'),
      }),
    });
    const result = await check.json();
    const code = result?.code?.toString();
    const status = code === '00' ? 'success' : 'failed';
    const providerTx = result?.data?.transaction_id ?? result?.data?.cpm_trans_id ?? transactionId;
    const { error } = await supabase.rpc('aml_confirm_wallet_payment', {
      p_transaction_id: transactionId,
      p_provider_transaction_id: providerTx,
      p_status: status,
      p_metadata: result,
    });
    if (error) throw error;
    return Response.json({ ok: true });
  } catch (e) {
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
