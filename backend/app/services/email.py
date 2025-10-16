from __future__ import annotations

import html
import logging
from typing import Optional

import anyio
from email.utils import parseaddr
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Email, Content

from app.config import settings

logger = logging.getLogger("app.services.email")


def _is_valid_email(address: str) -> bool:
    name, email_addr = parseaddr(address or "")
    return bool(email_addr and "@" in email_addr and "." in email_addr.split("@")[-1])


class EmailService:
    """
    Transactional email service using SendGrid.
    - Non-blocking within async endpoints via thread offloading.
    - HTML is caller-provided; sanitize user-supplied tokens with sanitize_html().
    """

    def __init__(self):
        api_key = getattr(settings, "SENDGRID_API_KEY", None)
        from_addr = getattr(settings, "FROM_EMAIL", None)
        if not api_key or not from_addr:
            logger.warning("Email service not fully configured (SENDGRID_API_KEY/FROM_EMAIL missing)")
        self.client = SendGridAPIClient(api_key) if api_key else None
        self.from_email = Email(from_addr) if from_addr else None

    @staticmethod
    def sanitize_html(text: str) -> str:
        """Sanitize user-supplied text fragments to prevent HTML injection."""
        return html.escape(str(text or ""))

    async def send_email(
        self,
        to_email: str,
        subject: str,
        html_content: str,
        plain_content: Optional[str] = None,
    ) -> bool:
        """
        Send an email via SendGrid (runs the blocking client in a thread).
        Returns True on 2xx status code, else False.
        """
        if not self.client or not self.from_email:
            logger.error("SendGrid client not initialized or FROM_EMAIL missing")
            return False

        if not _is_valid_email(to_email):
            logger.error("Invalid recipient email: %s", to_email)
            return False

        # Basic subject hardening
        safe_subject = " ".join((subject or "").splitlines()).strip()[:250] or "NoctisApp"

        try:
            message = Mail(
                from_email=self.from_email,
                to_emails=to_email,
                subject=safe_subject,
            )

            # Prefer plain first, then HTML to support clients that choose best part
            if plain_content:
                message.add_content(Content("text/plain", plain_content))
            message.add_content(Content("text/html", html_content or ""))

            # Offload blocking send to a worker thread
            def _send_sync():
                return self.client.send(message)

            response = await anyio.to_thread.run_sync(_send_sync)

            if response and getattr(response, "status_code", 0) in (200, 201, 202, 204):
                logger.info("Email sent to %s (status=%s)", to_email, response.status_code)
                return True

            code = getattr(response, "status_code", "unknown")
            logger.error("Email send failed (status=%s) to %s", code, to_email)
            return False

        except Exception as e:
            logger.error("Email send error to %s: %s", to_email, str(e))
            return False

    async def send_verification_email(self, to_email: str, code: str) -> bool:
        """
        Send an OTP verification email (code should be a short numeric string).
        """
        safe_code = self.sanitize_html(code)

        subject = "Verify Your Email - NoctisApp"

        html_content = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    body {{
      font-family: Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      margin: 0;
      padding: 0;
    }}
    .container {{
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }}
    .header {{
      background: linear-gradient(135deg, #1976D2 0%, #1565C0 100%);
      color: white;
      padding: 30px;
      text-align: center;
      border-radius: 8px 8px 0 0;
    }}
    .content {{
      background: white;
      padding: 30px;
      border: 1px solid #e0e0e0;
    }}
    .code {{
      font-size: 36px;
      font-weight: bold;
      color: #1976D2;
      text-align: center;
      padding: 25px;
      background: #f5f5f5;
      border-radius: 8px;
      letter-spacing: 8px;
      margin: 20px 0;
    }}
    .footer {{
      color: #666;
      font-size: 12px;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #e0e0e0;
      text-align: center;
    }}
    .warning {{
      background: #fff3e0;
      border-left: 4px solid #ff9800;
      padding: 12px;
      margin: 20px 0;
    }}
    a {{ color: #1976D2; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0;">🌙 NoctisApp</h1>
      <p style="margin: 10px 0 0 0;">Secure Chat Platform</p>
    </div>
    <div class="content">
      <h2>Welcome to NoctisApp!</h2>
      <p>Thank you for registering. Please use the following code to verify your email address:</p>
      <div class="code">{safe_code}</div>
      <p><strong>This code will expire in 10 minutes.</strong></p>
      <div class="warning">
        <strong>⚠️ Security Notice:</strong> If you didn't request this verification, please ignore this email.
      </div>
    </div>
    <div class="footer">
      <p>© 2025 NoctisApp by Harshith TC. All rights reserved.</p>
      <p>This is an automated email. Please do not reply.</p>
      <p style="margin-top: 10px;">
        <a href="mailto:appnoctis@gmail.com">Support</a>
      </p>
    </div>
  </div>
</body>
</html>
        """

        plain_content = f"""Welcome to NoctisApp!

Your verification code is: {safe_code}

This code will expire in 10 minutes.

If you didn't request this verification, please ignore this email.

---
NoctisApp - Secure Chat Platform
© 2025 Harshith TC
Support: appnoctis@gmail.com
"""

        return await self.send_email(to_email, subject, html_content, plain_content)

    async def send_password_reset_email(self, to_email: str, reset_token: str) -> bool:
        """
        Send a password reset email with a time-limited link.
        """
        safe_token = self.sanitize_html(reset_token)

        # Build reset link based on environment
        if getattr(settings, "DEBUG", False):
            reset_link = f"http://localhost:3000/reset-password?token={safe_token}"
        else:
            reset_link = f"https://noctisapp.com/reset-password?token={safe_token}"

        subject = "Password Reset Request - NoctisApp"

        html_content = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    body {{
      font-family: Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      margin: 0;
      padding: 0;
    }}
    .container {{
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }}
    .header {{
      background: linear-gradient(135deg, #d32f2f 0%, #c62828 100%);
      color: white;
      padding: 30px;
      text-align: center;
      border-radius: 8px 8px 0 0;
    }}
    .content {{
      background: white;
      padding: 30px;
      border: 1px solid #e0e0e0;
    }}
    .button {{
      display: inline-block;
      padding: 15px 30px;
      background: #1976D2;
      color: white !important;
      text-decoration: none;
      border-radius: 5px;
      margin: 20px 0;
      font-weight: bold;
    }}
    .footer {{
      color: #666;
      font-size: 12px;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #e0e0e0;
      text-align: center;
    }}
    .warning {{
      background: #ffebee;
      border-left: 4px solid #d32f2f;
      padding: 15px;
      margin: 20px 0;
    }}
    .security {{
      background: #e3f2fd;
      border-left: 4px solid #1976D2;
      padding: 15px;
      margin: 20px 0;
    }}
    a {{ color: #1976D2; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0;">🔒 Password Reset</h1>
      <p style="margin: 10px 0 0 0;">NoctisApp Security</p>
    </div>
    <div class="content">
      <h2>Password Reset Request</h2>
      <p>We received a request to reset your password for your NoctisApp account.</p>
      <p>Click the button below to reset your password:</p>
      <div style="text-align: center;">
        <a href="{reset_link}" class="button">Reset Password</a>
      </div>
      <p style="text-align: center; color: #666; margin-top: 10px;">
        Or copy this link:<br />
        <span style="font-size: 11px; word-break: break-all;">{reset_link}</span>
      </p>
      <div class="security">
        <strong>⏱️ Time Limit:</strong> This link will expire in 1 hour.
      </div>
      <div class="warning">
        <strong>⚠️ Important Security Notice:</strong><br />
        If you didn't request this password reset, please ignore this email and your password will remain unchanged.
        Consider changing your password immediately if you suspect unauthorized access.
      </div>
      <p><strong>Security Tips:</strong></p>
      <ul>
        <li>Never share this link with anyone</li>
        <li>Check that the link goes to noctisapp.com</li>
        <li>Use a strong, unique password</li>
      </ul>
    </div>
    <div class="footer">
      <p>© 2025 NoctisApp by Harshith TC. All rights reserved.</p>
      <p>This is an automated security email. Please do not reply.</p>
      <p style="margin-top: 10px;">
        <a href="mailto:appnoctis@gmail.com">Support</a> |
        <a href="mailto:appnoctis@gmail.com">Security</a>
      </p>
    </div>
  </div>
</body>
</html>
        """

        plain_content = f"""Password Reset Request - NoctisApp

We received a request to reset your password for your NoctisApp account.

Open this link to reset your password:
{reset_link}

This link will expire in 1 hour.

IMPORTANT: If you didn't request this password reset, please ignore this email and your password will remain unchanged.

Security Tips:
- Never share this link with anyone
- Use a strong, unique password
- Check that the link goes to noctisapp.com

---
NoctisApp - Secure Chat Platform
© 2025 Harshith TC
Support: appnoctis@gmail.com
Security: harshithtc30@gmail.com
"""

        return await self.send_email(to_email, subject, html_content, plain_content)
