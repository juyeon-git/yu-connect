/* eslint-disable */
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const mime = require("mime-types");
const request = require('request');

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

//
// 4) [추가] Storage 파일 Content-Type 자동 보정 (신규 업로드용)
//
exports.fixContentTypeOnFinalize = onObjectFinalized(async (event) => {
  const obj = event.data;
  if (!obj || !obj.name || !obj.bucket) return;

  // 이미 image/* 면 스킵
  if (obj.contentType && obj.contentType.startsWith("image/")) return;

  const guessed = mimeTypes.getType(obj.name) || "image/jpeg";
  if (!guessed.startsWith("image/")) return; // 이미지가 아니면 스킵(필요 시 정책에 맞게 수정)

  const bucket = getStorage().bucket(obj.bucket);
  const file = bucket.file(obj.name);

  console.log(`Fixing contentType for ${obj.name} -> ${guessed}`);
  await file.setMetadata({
    contentType: guessed,
    metadata: obj.metadata || {}, // 기존 커스텀 메타 유지
  });
  return;
});

//
// 5) [추가] 기존 폴더 일괄 보정용 HTTP 함수
//    호출 예: /fixContentTypeForFolder?folder=complaints/CIQtAX.../&key=YOUR_KEY
//    process.env.FIX_KEY 가 설정되어 있으면 ?key 검증, 없으면 검증 생략
//
exports.fixContentTypeForFolder = onRequest(async (req, res) => {
  try {
    const requiredKey = process.env.FIX_KEY;
    const provided = req.query.key;
    if (requiredKey && provided !== requiredKey) {
      return res.status(403).send("Forbidden");
    }

    const folder = req.query.folder;
    if (!folder || typeof folder !== "string") {
      return res.status(400).send("Missing ?folder=complaints/<docId>/");
    }

    const bucket = getStorage().bucket();
    const [files] = await bucket.getFiles({ prefix: folder });

    let updated = 0;
    for (const f of files) {
      const [meta] = await f.getMetadata();
      const cur = meta.contentType || "";
      if (cur.startsWith("image/")) continue;

      const guessed = mimeTypes.getType(f.name) || "image/jpeg";
      if (!guessed.startsWith("image/")) continue;

      await f.setMetadata({
        contentType: guessed,
        metadata: meta.metadata || {},
      });
      updated++;
    }

    return res.status(200).send(`Updated ${updated} files under ${folder}`);
  } catch (e) {
    console.error(e);
    return res.status(500).send(e?.message || "Internal error");
  }
});

exports.getImage = functions.https.onRequest((req, res) => {
  const url = req.query.url;

  if (!url) {
    res.status(400).send('URL이 필요합니다.');
    return;
  }

  // Firebase Storage URL을 요청하고 결과를 반환
  request(url)
    .on('error', (err) => {
      console.error('이미지 요청 실패:', err);
      res.status(500).send('이미지 요청 실패');
    })
    .pipe(res);
});
