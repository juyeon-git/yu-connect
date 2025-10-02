/* eslint-disable */
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

try { admin.app(); } catch (e) { admin.initializeApp(); }

const db = getFirestore();
const auth = admin.auth();
const messaging = getMessaging();

// 선택: 서울 리전에 고정하고 싶다면 아래 옵션을 각 트리거에 추가하세요.
// 예) onDocumentCreated({ region: 'asia-northeast3' }, "path", handler)
// const REGION = 'asia-northeast3';

//
// 공용 헬퍼: 사용자 fcmTokens 읽기/정리
//
async function getUserTokens(uid) {
  if (!uid) return [];
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return [];
  const data = snap.data() || {};
  const arr = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
  // 문자열 토큰만 필터 + 중복 제거
  return Array.from(new Set(arr.filter(t => typeof t === "string" && t.length > 0)));
}

async function removeInvalidTokens(uid, tokens) {
  if (!uid || !tokens || tokens.length === 0) return;
  try {
    await db.collection("users").doc(uid).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
    });
  } catch (e) {
    // 문서 없음/필드 없음 등은 무시
    console.warn("토큰 정리 중 경고:", e?.message || e);
  }
}

async function sendToUser(uid, payload) {
  const tokens = await getUserTokens(uid);
  if (tokens.length === 0) return { successCount: 0, failureCount: 0 };

  const resp = await messaging.sendEachForMulticast({
    tokens,
    notification: payload.notification,
    data: payload.data || {},
  });

  // 무효 토큰 정리
  const invalid = [];
  resp.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code || "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalid.push(tokens[i]);
      }
    }
  });
  if (invalid.length > 0) {
    await removeInvalidTokens(uid, invalid);
    console.log("무효 토큰 정리:", invalid.length);
  }

  console.log("FCM 전송 결과:", resp.successCount, "성공 /", resp.failureCount, "실패");
  return resp;
}

function statusLabel(s) {
  switch ((s || "").toString()) {
    case "received":
    case "pending":
      return "접수";
    case "processing":
    case "inProgress":
      return "처리중";
    case "done":
      return "완료";
    default:
      return (s || "").toString();
  }
}

//
// 1) 민원 상태 변경 → 소유자에게 푸시
//
exports.onComplaintStatusChange = onDocumentUpdated("complaints/{id}", async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();
  if (!before || !after) return null;

  // 상태 변경 없으면 무시
  if ((before.status || "") === (after.status || "")) return null;

  const ownerUid = after.ownerUid;
  if (!ownerUid) return null;

  const title = (after.title || "민원").toString();
  const body  = `‘${title}’ 상태가 ‘${statusLabel(after.status)}’로 변경되었습니다.`;

  try {
    await sendToUser(ownerUid, {
      notification: { title: "민원 상태 변경", body },
      data: {
        type: "status",
        complaintId: event.params.id,
        ownerUid: ownerUid,
        status: (after.status || "").toString(),
      },
    });
  } catch (e) {
    console.error("상태 변경 알림 실패:", e);
  }
  return null;
});

//
// 2) 관리자 답변 등록 → 소유자에게 푸시
//
exports.onReplyAdded = onDocumentCreated("complaints/{complaintId}/replies/{replyId}", async (event) => {
  const reply = event.data.data();
  if (!reply) return null;

  // 관리자 답변만 발송
  if ((reply.senderRole || "") !== "admin") return null;

  const complaintId = event.params.complaintId;
  const compSnap = await db.collection("complaints").doc(complaintId).get();
  if (!compSnap.exists) return null;

  const comp = compSnap.data() || {};
  const ownerUid = comp.ownerUid;
  if (!ownerUid) return null;

  const msg = (reply.message || "관리자가 답변을 추가했습니다.").toString();
  const body = msg.length > 120 ? `${msg.slice(0, 117)}…` : msg; // 너무 길면 자르기

  try {
    await sendToUser(ownerUid, {
      notification: { title: "민원 답변 등록", body },
      data: {
        type: "reply",
        complaintId: complaintId,
        ownerUid: ownerUid,
        replyId: event.params.replyId,
      },
    });
  } catch (e) {
    console.error("답변 알림 실패:", e);
  }
  return null;
});

//
// 3) 관리자 승인 흐름 (중복 제거 버전)
//    - onAdminCreated / onAdminUpdated / bootstrapSuperAdmin / approveAdmin / rejectAdmin
//
exports.onAdminCreated = onDocumentCreated("admins/{uid}", async (event) => {
  const uid  = event.params.uid;
  const data = event.data.data() || {};
  const role = data.role || "pending";

  if (role === "admin" || role === "superAdmin") {
    await auth.setCustomUserClaims(uid, { role });
  } else {
    await auth.setCustomUserClaims(uid, {}); // pending/기타 → 권한 제거
  }
  return null;
});

exports.onAdminUpdated = onDocumentUpdated("admins/{uid}", async (event) => {
  const uid    = event.params.uid;
  const before = event.data.before.data() || {};
  const after  = event.data.after.data() || {};
  const bRole  = before.role || "pending";
  const aRole  = after.role  || "pending";
  if (bRole === aRole) return null;

  if (aRole === "admin" || aRole === "superAdmin") {
    await auth.setCustomUserClaims(uid, { role: aRole });
  } else {
    await auth.setCustomUserClaims(uid, {}); // 권한 제거
  }
  return null;
});

exports.bootstrapSuperAdmin = onCall(async (req) => {
  const caller = req.auth;
  if (!caller) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

  // 이미 superAdmin 존재 여부
  const exists = await db.collection("admins").where("role", "==", "superAdmin").limit(1).get();
  if (!exists.empty) throw new HttpsError("failed-precondition", "이미 슈퍼관리자가 존재합니다.");

  const uid   = caller.uid;
  const email = caller.token?.email || "";
  const now   = admin.firestore.FieldValue.serverTimestamp();

  await db.collection("admins").doc(uid).set({
    uid,
    email,
    name: email ? email.split("@")[0] : "superadmin",
    role: "superAdmin",
    approvedBy: uid,
    createdAt: now,
    updatedAt: now,
  }, { merge: true });

  await auth.setCustomUserClaims(uid, { role: "superAdmin" });
  return { ok: true };
});

exports.approveAdmin = onCall(async (req) => {
  const caller = req.auth;
  if (!caller) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  if ((caller.token?.role || "") !== "superAdmin") {
    throw new HttpsError("permission-denied", "슈퍼관리자만 승인할 수 있습니다.");
  }

  const targetUid = req.data?.targetUid;
  if (!targetUid) throw new HttpsError("invalid-argument", "targetUid가 필요합니다.");

  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("admins").doc(targetUid).set({
    role: "admin",
    approvedBy: caller.uid,
    updatedAt: now,
  }, { merge: true });

  await auth.setCustomUserClaims(targetUid, { role: "admin" });
  return { ok: true };
});

exports.rejectAdmin = onCall(async (req) => {
  const caller = req.auth;
  if (!caller) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  if ((caller.token?.role || "") !== "superAdmin") {
    throw new HttpsError("permission-denied", "총 관리자만 가능합니다.");
  }

  const targetUid = req.data?.targetUid;
  if (!targetUid) throw new HttpsError("invalid-argument", "targetUid가 필요합니다.");

  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("admins").doc(targetUid).set({
    role: "pending",
    approvedBy: admin.firestore.FieldValue.delete(),
    updatedAt: now,
  }, { merge: true });

  await auth.setCustomUserClaims(targetUid, {}); // 권한 제거
  return { ok: true };
});
