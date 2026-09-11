const CODAVYBES_LOGO_URL = 'https://codavybes.vercel.app/brand/codavybes-logo.png'

function otpEmailHtml(code: string) {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="x-apple-disable-message-reformatting"><title>Verify your sign in</title></head>
<body style="margin:0;padding:0;background:#F6F7FA;color:#151821;font-family:Inter,Segoe UI,Arial,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">Your 4-digit CodaVybes verification code.</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;background:#F6F7FA;margin:0;padding:0;"><tr><td align="center" style="padding:32px 16px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:600px;">
<tr><td align="center" style="padding:0 0 18px;"><img src="https://codavybes.vercel.app/brand/codavybes-logo.png" width="180" alt="CodaVybes" style="display:block;width:180px;max-width:70%;height:auto;border:0;outline:none;text-decoration:none;"></td></tr>
<tr><td style="background:#FFFFFF;border:1px solid #E3E6EE;border-radius:18px;padding:38px 34px;box-shadow:0 8px 30px rgba(7,21,27,.06);">
<div style="font-size:12px;line-height:18px;font-weight:800;letter-spacing:1.8px;text-transform:uppercase;color:#FF7A1C;margin:0 0 12px;">CODAVYBES</div>
<h1 style="margin:0 0 14px;font-size:28px;line-height:36px;font-weight:800;letter-spacing:-.6px;color:#151821;">Verify your sign in</h1>
<p style="margin:0 0 24px;font-size:15px;line-height:24px;color:#6F7888;">Enter this 4-digit code in CodaVybes. It expires in 5 minutes.</p>
<div style="margin:24px 0 8px;padding:24px 18px;text-align:center;border-radius:16px;background:#07151B;"><div style="font-size:11px;line-height:16px;font-weight:800;letter-spacing:1.6px;text-transform:uppercase;color:#FF8A2A;margin-bottom:10px;">Your verification code</div><div style="font-size:40px;line-height:48px;font-weight:900;letter-spacing:12px;color:#FFFFFF;">${code}</div></div><div style="margin:22px 0 4px;padding:15px 16px;border-radius:14px;background:#FFF5DC;border:1px solid #F3E4B8;color:#5B4A22;font-size:13px;line-height:20px;">The code expires in <strong>5 minutes</strong>. Never share it with anyone.</div>
<div style="height:1px;background:#E3E6EE;margin:30px 0 22px;"></div>
<p style="margin:0;font-size:12px;line-height:19px;color:#9199A8;">If you did not request this, you can safely ignore this email.</p>
</td></tr>
<tr><td align="center" style="padding:20px 12px 0;"><p style="margin:0 0 5px;font-size:12px;line-height:18px;color:#6F7888;">CodaVybes · Premium social playground</p><p style="margin:0;font-size:11px;line-height:18px;color:#9199A8;">Powered by CodaBite</p></td></tr>
</table></td></tr></table></body></html>`
}

// In the existing Resend request use:
// html: otpEmailHtml(code),
