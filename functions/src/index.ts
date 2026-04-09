import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions/v2';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';
import * as nodemailer from 'nodemailer';

admin.initializeApp();

// ─── Secrets ──────────────────────────────────────────────────────────────────
// Set via:
//   firebase functions:secrets:set EMAIL_USER
//   firebase functions:secrets:set EMAIL_PASS

const EMAIL_USER = defineSecret('EMAIL_USER');
const EMAIL_PASS = defineSecret('EMAIL_PASS');

// ─── Trigger: course_requests status change ───────────────────────────────────

export const onRequestStatusChange = onDocumentUpdated(
  {
    document: 'course_requests/{requestId}',
    secrets: [EMAIL_USER, EMAIL_PASS],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    // Only proceed if status actually changed
    if (before.status === after.status) return;

    const newStatus: string = after.status;
    if (newStatus !== 'approved' && newStatus !== 'declined') return;

    // Fetch client info
    const clientId: string = after.clientId;
    const clientDoc = await admin
      .firestore()
      .collection('users')
      .doc(clientId)
      .get();

    if (!clientDoc.exists) {
      logger.warn(`Client ${clientId} not found — skipping email.`);
      return;
    }

    const clientData = clientDoc.data()!;
    const clientEmail: string = clientData.email;
    const clientName: string = clientData.displayName ?? 'there';
    const courseTitle: string = after.title ?? 'your course';
    const declineReason: string | undefined = after.declineReason;

    const { subject, html } =
      newStatus === 'approved'
        ? buildApprovedEmail(clientName, courseTitle)
        : buildDeclinedEmail(clientName, courseTitle, declineReason);

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: EMAIL_USER.value(),
        pass: EMAIL_PASS.value(),
      },
    });

    await transporter.sendMail({
      from: `"The Training Triangle" <${EMAIL_USER.value()}>`,
      to: clientEmail,
      subject,
      html,
    });

    logger.info(`Email sent to ${clientEmail} — status: ${newStatus}`);
  }
);

// ─── Email templates ──────────────────────────────────────────────────────────

function buildApprovedEmail(
  name: string,
  courseTitle: string
): { subject: string; html: string } {
  return {
    subject: `Your training request has been approved — ${courseTitle}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; background: #ffffff;">
        <div style="background: linear-gradient(135deg, #2DB89E, #1A9980); border-radius: 12px; padding: 32px; margin-bottom: 24px; text-align: center;">
          <h1 style="color: #ffffff; font-size: 22px; margin: 0;">The Training Triangle</h1>
        </div>

        <h2 style="color: #111111; font-size: 20px; font-weight: 800; margin-bottom: 8px;">
          Your request has been approved
        </h2>
        <p style="color: #475569; font-size: 15px; line-height: 1.6;">
          Hi ${name},
        </p>
        <p style="color: #475569; font-size: 15px; line-height: 1.6;">
          Great news — your training request for <strong>${courseTitle}</strong> has been approved.
          Your training company has assigned a trainer and scheduled the session.
        </p>
        <p style="color: #475569; font-size: 15px; line-height: 1.6;">
          Log in to the app to view your course details, including the date, time, trainer, and venue.
        </p>

        <div style="background: #F0FDF9; border-left: 4px solid #2DB89E; border-radius: 8px; padding: 16px; margin: 24px 0;">
          <p style="color: #1A7A6B; font-size: 14px; font-weight: 700; margin: 0;">
            Next step: open the app and check your Bookings tab for full details.
          </p>
        </div>

        <p style="color: #94A3B8; font-size: 13px; margin-top: 32px; border-top: 1px solid #F1F5F9; padding-top: 16px;">
          This is an automated message from The Training Triangle. Please do not reply to this email.
        </p>
      </div>
    `,
  };
}

function buildDeclinedEmail(
  name: string,
  courseTitle: string,
  reason?: string
): { subject: string; html: string } {
  const reasonBlock = reason
    ? `
      <div style="background: #FEF2F2; border-left: 4px solid #EF4444; border-radius: 8px; padding: 16px; margin: 24px 0;">
        <p style="color: #991B1B; font-size: 13px; font-weight: 700; margin: 0 0 4px 0;">Reason provided:</p>
        <p style="color: #7F1D1D; font-size: 14px; margin: 0;">${reason}</p>
      </div>
    `
    : '';

  return {
    subject: `Update on your training request — ${courseTitle}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; background: #ffffff;">
        <div style="background: linear-gradient(135deg, #2DB89E, #1A9980); border-radius: 12px; padding: 32px; margin-bottom: 24px; text-align: center;">
          <h1 style="color: #ffffff; font-size: 22px; margin: 0;">The Training Triangle</h1>
        </div>

        <h2 style="color: #111111; font-size: 20px; font-weight: 800; margin-bottom: 8px;">
          Your request was not approved
        </h2>
        <p style="color: #475569; font-size: 15px; line-height: 1.6;">
          Hi ${name},
        </p>
        <p style="color: #475569; font-size: 15px; line-height: 1.6;">
          Unfortunately your training request for <strong>${courseTitle}</strong> has been declined by your training company.
        </p>
        ${reasonBlock}
        <p style="color: #475569; font-size: 15px; line-height: 1.6;">
          You can submit a new request through the app at any time.
        </p>

        <p style="color: #94A3B8; font-size: 13px; margin-top: 32px; border-top: 1px solid #F1F5F9; padding-top: 16px;">
          This is an automated message from The Training Triangle. Please do not reply to this email.
        </p>
      </div>
    `,
  };
}
