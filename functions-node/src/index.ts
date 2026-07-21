import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { FunFactCategory, pickRandomFunFact } from "./funFacts";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

interface OwnerAggregate {
  ownerUid: string;
  hasCrops: boolean;
  hasLivestock: boolean;
  dueTaskTitles: string[];
}

interface NotificationPayload {
  title: string;
  body: string;
  actionUrl: string;
}

function todayUtcRange(): { start: Date; end: Date } {
  const now = new Date();
  const start = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
  );
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return { start, end };
}

function categoryFor(aggregate: OwnerAggregate): FunFactCategory {
  if (aggregate.hasCrops && aggregate.hasLivestock) {
    return Math.random() < 0.5 ? "crop" : "livestock";
  }
  if (aggregate.hasCrops) {
    return "crop";
  }
  if (aggregate.hasLivestock) {
    return "livestock";
  }
  return "general";
}

async function sendToTokens(
  tokens: string[],
  ownerUid: string,
  payload: NotificationPayload
): Promise<void> {
  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: { actionUrl: payload.actionUrl },
  });

  const staleTokens: string[] = [];
  response.responses.forEach((result, index) => {
    if (result.success) {
      return;
    }
    const code = result.error?.code ?? "";
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      staleTokens.push(tokens[index]);
    }
  });

  if (staleTokens.length > 0) {
    await db
      .collection("users")
      .doc(ownerUid)
      .update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
      });
  }
}

/**
 * Runs every morning: builds a per-farm-owner task digest and a fun fact
 * (tailored to whether they run crops, livestock, or both), then sends both
 * via FCM. Fires regardless of whether the app is open — this is the
 * server-side counterpart to the client's local task reminders.
 */
export const dailyDigest = onSchedule(
  {
    schedule: "every day 07:00",
    timeZone: "Africa/Lagos",
  },
  async () => {
    const { start, end } = todayUtcRange();
    const farmsSnapshot = await db.collection("farms").get();

    const aggregates = new Map<string, OwnerAggregate>();

    for (const doc of farmsSnapshot.docs) {
      const farm = doc.data();
      const ownerUid = farm.ownerUid as string | undefined;
      if (!ownerUid) {
        continue;
      }

      const farmType = farm.farmType as string | undefined;
      const supportsCrops =
        farmType === "crop" || farmType === "greenhouse" || farmType === "combined";
      const supportsLivestock = farmType === "livestock" || farmType === "combined";

      const aggregate: OwnerAggregate =
        aggregates.get(ownerUid) ?? {
          ownerUid,
          hasCrops: false,
          hasLivestock: false,
          dueTaskTitles: [],
        };
      aggregate.hasCrops = aggregate.hasCrops || supportsCrops;
      aggregate.hasLivestock = aggregate.hasLivestock || supportsLivestock;

      const tasks = Array.isArray(farm.workspaceTasks) ? farm.workspaceTasks : [];
      for (const task of tasks) {
        if (!task || task.status === "done") {
          continue;
        }
        const dueAt =
          typeof task.dueAt === "string" ? new Date(task.dueAt) : null;
        if (dueAt && dueAt >= start && dueAt < end) {
          aggregate.dueTaskTitles.push(String(task.title ?? "Farm task"));
        }
      }

      aggregates.set(ownerUid, aggregate);
    }

    let notified = 0;
    for (const aggregate of aggregates.values()) {
      const userSnapshot = await db.collection("users").doc(aggregate.ownerUid).get();
      const user = userSnapshot.data();
      if (!user || user.dailyUpdatesEnabled === false) {
        continue;
      }

      const tokens: string[] = Array.isArray(user.fcmTokens)
        ? user.fcmTokens.filter((token: unknown): token is string => typeof token === "string")
        : [];
      if (tokens.length === 0) {
        continue;
      }

      if (aggregate.dueTaskTitles.length > 0) {
        const preview = aggregate.dueTaskTitles.slice(0, 2).join(", ");
        await sendToTokens(tokens, aggregate.ownerUid, {
          title: `You have ${aggregate.dueTaskTitles.length} task${
            aggregate.dueTaskTitles.length === 1 ? "" : "s"
          } today`,
          body: preview,
          actionUrl: "/farm-tasks",
        });
      }

      const fact = pickRandomFunFact(categoryFor(aggregate));
      await sendToTokens(tokens, aggregate.ownerUid, {
        title: "Did you know?",
        body: fact.fact,
        actionUrl: `/learn/lesson/${fact.lessonId}`,
      });

      notified += 1;
    }

    console.log(
      `dailyDigest: processed ${aggregates.size} farm owner(s), notified ${notified}.`
    );
  }
);
