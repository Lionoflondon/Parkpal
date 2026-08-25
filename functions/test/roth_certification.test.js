const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Hard guard: certification may only talk to the local emulator.
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') {
  throw new Error('Roth certification requires FIRESTORE_EMULATOR_HOST=127.0.0.1:8080');
}
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, collection, addDoc} = require('firebase/firestore');
const admin = require('firebase-admin');
const {RothFinanceService} = require('../lib/roth_finance');
const {settleApprovedMissionReward} = require('../lib/roth_mission_settlement');

const projectId = 'demo-parkpal-roth';
admin.initializeApp({projectId});
let env;
let db;
let service;

test.before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
  db = admin.firestore();
  service = new RothFinanceService(db);
});
test.beforeEach(async () => { await env.clearFirestore(); });
test.after(async () => { await env.cleanup(); });

test('security suite: customer can read own wallet but not write or read another', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(setDoc(doc(alice, 'parkpal_roth_wallets/alice'), {availableRoth: 9}));
  await assertFails(getDoc(doc(alice, 'parkpal_roth_wallets/bob')));
  await assertFails(setDoc(doc(alice, 'parkpal_roth_ledger/e1'), {userId: 'alice', amountRoth: 1}));
  await assertFails(setDoc(doc(alice, 'parkpal_roth_events/e1'), {userId: 'alice'}));
  await assertFails(setDoc(doc(alice, 'parkpal_roth_reservations/r1'), {userId: 'alice', amountRoth: 1}));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'parkpal_roth_wallets/alice')));
  await assertFails(getDoc(doc(bob, 'parkpal_roth_wallets/alice')));
});

test('finance suite: atomic idempotent credit and overspend protection', async () => {
  const credits = await Promise.all(Array.from({length: 8}, () => service.mutate({userId: 'u1', amountRoth: 1, type: 'reward_credit', direction: 'credit', sourceType: 'test', sourceId: 's', idempotencyKey: 'same-key', description: 'test', createdBy: 'test'})));
  assert.equal(new Set(credits.map((x) => x.entryId)).size, 1);
  await service.mutate({userId: 'u2', amountRoth: 5, type: 'admin_credit', direction: 'credit', sourceType: 'test', sourceId: 'seed', idempotencyKey: 'seed-u2', description: 'seed', createdBy: 'test'});
  const debits = await Promise.allSettled([1, 2].map((i) => service.mutate({userId: 'u2', amountRoth: 4, type: 'admin_debit', direction: 'debit', sourceType: 'test', sourceId: String(i), idempotencyKey: `debit-${i}`, description: 'debit', createdBy: 'test'})));
  assert.equal(debits.filter((x) => x.status === 'fulfilled').length, 1);
  const wallet = (await admin.firestore().doc('parkpal_roth_wallets/u2').get()).data();
  assert.equal(wallet.availableRoth, 1);
});

test('reservation suite: hold, release and settle are mutually exclusive', async () => {
  await service.mutate({userId: 'u3', amountRoth: 5, type: 'admin_credit', direction: 'credit', sourceType: 'test', sourceId: 'seed', idempotencyKey: 'seed-u3', description: 'seed', createdBy: 'test'});
  await Promise.allSettled([1, 2].map((i) => service.reserve('u3', 4, `r${i}`, 'test')));
  const wallet = (await admin.firestore().doc('parkpal_roth_wallets/u3').get()).data();
  assert.equal(wallet.reservedRoth, 4);
  assert.equal(wallet.availableRoth, 1);
  await service.releaseReservation('r1').catch(() => service.releaseReservation('r2'));
});

test('mission suite: only approved completed mission settles once', async () => {
  await admin.firestore().doc('parkpal_pioneer_missions/m1').set({assignedToUserId: 'u4', status: 'completed', rewardApprovalStatus: 'approved', rewardRoth: 1});
  const first = await settleApprovedMissionReward(admin.firestore(), service, 'm1', 'admin');
  const second = await settleApprovedMissionReward(admin.firestore(), service, 'm1', 'admin');
  assert.equal(first.entryId, second.entryId);
  assert.equal((await admin.firestore().doc('parkpal_roth_wallets/u4').get()).data().availableRoth, 1);
});

test('reconciliation suite: corrupted wallet projection is detected', async () => {
  await admin.firestore().doc('parkpal_roth_wallets/u4').set({availableRoth: 99}, {merge: true});
  const result = await service.reconcile('u4');
  assert.equal(result.ok, false);
  assert.ok(result.discrepancies.includes('availableRoth'));
});
