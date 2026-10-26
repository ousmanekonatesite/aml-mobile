import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const CINETPAY_URL = 'https://api-checkout.cinetpay.com/v2/payment';

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const auth = req.headers.get('Authorization');
    if (!auth) return Response.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
    const token = auth.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) return Response.json({ error: 'AUTH_REQUIRED' }, { status: 401 });

    const body = await req.json();
    const amount = Number(body.amount);
    const credits = Number(body.credits);
    if (!Number.isInteger(amount) || amount < 100 || amount % 5 !== 0 || !Number.isInteger(credits) || credits <= 0) {
      return Response.json({ error: 'INVALID_PACK' }, { status: 400 });
    }

    const transactionId = `AML-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const notifyUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/cinetpay-notify`;
    const returnUrl = Deno.env.get('CINETPAY_RETURN_URL') ?? 'https://aml-ci.com/';

    const { error: insertError } = await supabase.from('wallet_payment_intents').insert({
      user_id: user.id,
      transaction_id: transactionId,
      amount_xof: amount,
      credits,
      status: 'pending',
      metadata: { source: 'aml_arena' },
    });
    if (insertError) throw insertError;

    const response = await fetch(CINETPAY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        apikey: Deno.env.get('CINETPAY_APIKEY'),
        site_id: Deno.env.get('CINETPAY_SITE_ID'),
        transaction_id: transactionId,
        amount,
        currency: 'XOF',
        description: `Achat de ${credits} crédits AML`,
        customer_id: user.id,
        customer_name: user.user_metadata?.first_name ?? 'AML',
        customer_surname: user.user_metadata?.last_name ?? 'Arena',
        customer_email: user.email ?? 'noreply@aml-ci.com',
        notify_url: notifyUrl,
        return_url: returnUrl,
        channels: 'ALL',
        lang: 'fr',
        metadata: JSON.stringify({ user_id: user.id, credits }),
      }),
    });
    const data = await response.json();
    const paymentUrl = data?.data?.payment_url;
    if (!response.ok || !paymentUrl) {
      await supabase.from('wallet_payment_intents').update({ status: 'failed', metadata: data }).eq('transaction_id', transactionId);
      return Response.json({ error: 'CINETPAY_INIT_FAILED', details: data }, { status: 502 });
    }
    await supabase.from('wallet_payment_intents').update({ payment_url: paymentUrl, status: 'waiting', metadata: data }).eq('transaction_id', transactionId);
    return Response.json({ transaction_id: transactionId, payment_url: paymentUrl });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
