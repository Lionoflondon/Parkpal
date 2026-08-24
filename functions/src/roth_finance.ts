import * as admin from "firebase-admin";

export const ROTH_LEDGER = "parkpal_roth_ledger";
export const ROTH_WALLETS = "parkpal_roth_wallets";
export const ROTH_EVENTS = "parkpal_roth_events";
export const ROTH_AUDIT = "parkpal_roth_audit";
export const ROTH_MINOR_PER_UNIT = 100;

export type RothDirection = "credit" | "debit";
export type RothType = "admin_credit" | "admin_debit" | "reward_credit" | "redemption_debit" | "refund_credit" | "reversal" | "adjustment";

export interface RothMutation {
  userId: string;
  amountRoth: number;
  type: RothType;
  direction: RothDirection;
  sourceType: string;
  sourceId: string;
  idempotencyKey: string;
  description: string;
  createdBy: string;
  approvedBy?: string;
  reason?: string;
  metadata?: Record<string, unknown>;
}

export interface RothWallet {
  availableRoth: number;
  pendingRoth: number;
  reservedRoth: number;
  lifetimeEarnedRoth: number;
  lifetimeRedeemedRoth: number;
  lifetimeReversedRoth: number;
  version: number;
}

function validateAmount(amount: number): void {
  if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Roth amount must be a positive integer.");
}

function emptyWallet(): RothWallet {
  return {availableRoth: 0, pendingRoth: 0, reservedRoth: 0, lifetimeEarnedRoth: 0, lifetimeRedeemedRoth: 0, lifetimeReversedRoth: 0, version: 0};
}

export class RothFinanceService {
  constructor(private readonly db: admin.firestore.Firestore = admin.firestore()) {}

  async mutate(input: RothMutation): Promise<{entryId: string; wallet: RothWallet; duplicate: boolean}> {
    if (!input.userId || !input.sourceType || !input.sourceId || !input.idempotencyKey || !input.description) throw new Error("Missing Roth mutation identity.");
    validateAmount(input.amountRoth);
    const eventRef = this.db.collection(ROTH_EVENTS).doc(input.idempotencyKey);
    const walletRef = this.db.collection(ROTH_WALLETS).doc(input.userId);
    const ledgerRef = this.db.collection(ROTH_LEDGER).doc(input.idempotencyKey);
    return this.db.runTransaction(async (tx) => {
      const event = await tx.get(eventRef);
      const existing = event.data();
      if (event.exists && existing?.entryId) {
        const wallet = (await tx.get(walletRef)).data() ?? emptyWallet();
        return {entryId: String(existing.entryId), wallet: wallet as RothWallet, duplicate: true};
      }
      const current = ((await tx.get(walletRef)).data() ?? emptyWallet()) as RothWallet;
      const next = {...emptyWallet(), ...current};
      if (input.direction === "debit" && next.availableRoth < input.amountRoth) throw new Error("Insufficient Roth balance.");
      next.availableRoth += input.direction === "credit" ? input.amountRoth : -input.amountRoth;
      if (next.availableRoth < 0) throw new Error("Roth balance cannot be negative.");
      if (input.direction === "credit") next.lifetimeEarnedRoth += input.amountRoth;
      else next.lifetimeRedeemedRoth += input.amountRoth;
      next.version += 1;
      tx.create(ledgerRef, {
        entryId: ledgerRef.id, userId: input.userId, type: input.type, direction: input.direction,
        amountRoth: input.amountRoth, amountMinor: input.amountRoth * ROTH_MINOR_PER_UNIT,
        status: "settled", sourceType: input.sourceType, sourceId: input.sourceId,
        idempotencyKey: input.idempotencyKey, description: input.description,
        createdBy: input.createdBy, approvedBy: input.approvedBy ?? null, reason: input.reason ?? null,
        metadata: input.metadata ?? {}, createdAt: admin.firestore.FieldValue.serverTimestamp(),
        effectiveAt: admin.firestore.FieldValue.serverTimestamp(), reversalOf: null,
      });
      tx.set(walletRef, {...next, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
      tx.create(eventRef, {entryId: ledgerRef.id, userId: input.userId, idempotencyKey: input.idempotencyKey, createdAt: admin.firestore.FieldValue.serverTimestamp()});
      return {entryId: ledgerRef.id, wallet: next, duplicate: false};
    });
  }

  async reconcile(userId: string): Promise<{ok: boolean; expected: RothWallet; actual: RothWallet; discrepancies: string[]}> {
    const walletSnap = await this.db.collection(ROTH_WALLETS).doc(userId).get();
    const ledger = await this.db.collection(ROTH_LEDGER).where("userId", "==", userId).get();
    const expected = emptyWallet();
    for (const doc of ledger.docs) {
      const d = doc.data(); const amount = Number(d.amountRoth ?? 0);
      if (d.direction === "credit") { expected.availableRoth += amount; expected.lifetimeEarnedRoth += amount; }
      if (d.direction === "debit") { expected.availableRoth -= amount; expected.lifetimeRedeemedRoth += amount; }
      if (d.type === "reversal") expected.lifetimeReversedRoth += amount;
    }
    const actual = {...emptyWallet(), ...(walletSnap.data() ?? {})} as RothWallet;
    const discrepancies = Object.keys(expected).filter((k) => Number((expected as any)[k] ?? 0) !== Number((actual as any)[k] ?? 0));
    return {ok: discrepancies.length === 0, expected, actual, discrepancies};
  }
}
