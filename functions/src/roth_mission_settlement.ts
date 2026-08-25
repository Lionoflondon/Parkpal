import * as admin from "firebase-admin";
import {RothFinanceService} from "./roth_finance";

export async function settleApprovedMissionReward(db: admin.firestore.Firestore, service: RothFinanceService, missionId: string, actorUid: string): Promise<{entryId: string; duplicate: boolean}> {
  if (!missionId || !actorUid) throw new Error("Mission and actor are required.");
  const ref = db.collection("parkpal_pioneer_missions").doc(missionId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error("Mission not found.");
  const mission = snap.data() ?? {};
  const uid = String(mission.assignedToUserId ?? mission.assignedUserId ?? "");
  const status = String(mission.status ?? "").toLowerCase();
  const approval = String(mission.rewardApprovalStatus ?? mission.approvalStatus ?? "").toLowerCase();
  if (!uid || status !== "completed" || approval !== "approved" || mission.rewardReversed === true) throw new Error("Mission is not eligible for reward settlement.");
  const amount = Number(mission.rewardRoth);
  if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("Mission reward is invalid.");
  const result = await service.mutate({userId: uid, amountRoth: amount, type: "reward_credit", direction: "credit", sourceType: "mission", sourceId: missionId, idempotencyKey: `mission_reward:${missionId}:${uid}`, description: `Pioneer mission reward: ${missionId}`, createdBy: actorUid, approvedBy: String(mission.rewardApprovedBy ?? actorUid), metadata: {missionId}});
  await ref.set({rewardSettlementStatus: "settled", rewardLedgerEntryId: result.entryId, rewardRothSettled: amount, rewardSettledAt: admin.firestore.FieldValue.serverTimestamp(), rewardSettlementIdempotencyKey: `mission_reward:${missionId}:${uid}`}, {merge: true});
  return {entryId: result.entryId, duplicate: result.duplicate};
}
