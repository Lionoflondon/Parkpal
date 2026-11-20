# PARKPAL Stage 9C.1 — Hosted Merchant Activation

## Implemented locally

- Isolated integration work is based on prepared commit `d750a340e4f761b6bcc3c04c5b5837b68406903c` in `codex/roth-parkpal`; the existing checkout's unrelated Atlas edits are outside this worktree.
- Subscription, referral and promotion policies are read from `PARKPAL_ROTH_REWARD_POLICY`. Missing, malformed, unapproved or disabled policy fails closed. Amounts and per-customer lifetime limits come from the server policy, never from a client request.
- Subscription reward eligibility requires a signed Stripe webhook, a paid invoice with positive amount and payment-intent reference, a matching active subscription and customer, verified ParkPal email, no scheduled cancellation, and no known refund, dispute or early fraud warning.
- Stripe event receipts are marked processed only after event handling completes, allowing failed events to be retried. Stable invoice reward references and transactional issuance records prevent duplicate issuance.
- Refund, dispute, early-fraud-warning and cancellation events mark eligibility ineligible, or flag an already-issued reward for reversal review. Referral and promotion issuance also requires server-created eligibility evidence.
- ROTH reward issuance is limited to fresh TOTP-authenticated, email-verified, active PARKPAL administrators, enforced App Check, staging project allowlisting and company-scoped Secret Manager credentials. The central ROTH ledger remains the balance authority.
- PARKPAL's existing recurring Stripe subscriptions are unchanged. ROTH is not used as subscription tender.

## Activation gates

- The accessible Google Cloud project picker showed only production project `parkpal-prod`; no PARKPAL staging project was available. The production project's billing page showed a link to Firebase Payment account `016099-D80706-657B21`, which appears in the billing account list as closed. Production was not changed.
- The target CORPVS CHRISTI account `015276-1AC777-384534` is active. Its account page listed `corpus-christi-stg`, `corpus-christi-prod`, `rothcrossuk` and `portal-prod-f2308`. The console stopped responding before its budget and permissions could be verified.
- Creating and enabling the staging project, connecting it to the target billing account, configuring Firebase Auth/App Check, setting administrative MFA, and deploying require access that could not be verified from the Cloud Console/CLI session. No project, billing link, budget or cloud service was changed.
- PARKPAL reward issuance remains disabled: the current ROTH staging API has no verified reward-reversal endpoint. `ROTH_REWARD_REVERSALS_SUPPORTED` therefore remains false, and setting a policy flag alone cannot enable subscription rewards. Refund/cancellation reversals and settlement accounting require a central ROTH-approved reversal capability before any subscription reward is issued.
- Company registration and a company-scoped ROTH key/Secret Manager version require the ROTH single-owner staging onboarding workflow and synthetic issuance allowance. Coordination was sent to the active ROTH Stage 9C task; no fictitious administrator or credential was created.
- Actual hosted account linking, customer-wallet and operations-portal listing, synthetic reward issuance, cross-company allocation/redemption, funding attribution and financial reconciliation remain unverified.
- The prepared branch has not been pushed or deployed. Local tests and CI remain pending.

## Required continuation

1. Confirm the CORPVS staging billing account's permissions and cost alerts; provision or identify the isolated ParkPal staging project and attach only CORPVS CHRISTI billing.
2. Configure Firebase Auth, TOTP MFA, App Check, and a protected staging admin identity without creating additional administrators.
3. Complete ROTH owner-only PARKPAL merchant registration, allowance approval, and scoped credential creation; store each credential only in staging Secret Manager.
4. Add verified referral and promotion eligibility writers and central reward reversal support, then retain all three reward programs disabled until owner approval.
5. Push the isolated integration branch and use approved CI for full emulator/regression testing. Deploy only after the staging credentials and project configuration are available.
6. Run hosted acceptance with synthetic accounts and reconcile issuer funding, reward liability, cross-company redemption, refunds and settlement to zero unexplained pence.
