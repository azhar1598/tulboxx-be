import {
  BulkNotificationResponse,
  NotificationPayload,
  SendNotificationResponse,
} from "@/types/notification.types";
import * as admin from "firebase-admin";
import { ServiceAccount } from "firebase-admin";
import { Message, MessagingPayload } from "firebase-admin/messaging";

export class NotificationService {
  private readonly messaging: admin.messaging.Messaging;
  private deviceTokens: Set<string>;

  constructor(serviceAccount: ServiceAccount) {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }
    this.messaging = admin.messaging();
    this.deviceTokens = new Set<string>();
  }

  private createMessage(
    token: string,
    notification: NotificationPayload
  ): Message {
    return {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data,
      token,
    };
  }

  public async registerDevice(token: string): Promise<boolean> {
    try {
      // Validate token by attempting to send a test message
      await this.messaging.send({ token }, true);
      this.deviceTokens.add(token);
      return true;
    } catch (error) {
      const typedError = error as admin.FirebaseError;
      throw new Error(`Invalid token: ${typedError.message}`);
    }
  }

  public async unregisterDevice(token: string): Promise<void> {
    this.deviceTokens.delete(token);
  }

  public async sendToDevice(
    token: string,
    notification: NotificationPayload
  ): Promise<SendNotificationResponse> {
    try {
      const message = this.createMessage(token, notification);
      const messageId = await this.messaging.send(message);

      return {
        success: true,
        messageId,
      };
    } catch (error) {
      const typedError = error as admin.FirebaseError;

      if (
        typedError.code === "messaging/invalid-registration-token" ||
        typedError.code === "messaging/registration-token-not-registered"
      ) {
        await this.unregisterDevice(token);
      }

      return {
        success: false,
        error: typedError.message,
      };
    }
  }

  public async sendToMultipleDevices(
    notification: NotificationPayload
  ): Promise<BulkNotificationResponse> {
    const tokens = Array.from(this.deviceTokens);

    if (tokens.length === 0) {
      throw new Error("No registered devices found");
    }

    const messages = tokens.map((token) =>
      this.createMessage(token, notification)
    );

    try {
      const response = await this.messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: notification.title,
          body: notification.body,
        },
      });

      // Handle failed deliveries and clean up invalid tokens
      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          if (
            resp.error.code === "messaging/invalid-registration-token" ||
            resp.error.code === "messaging/registration-token-not-registered"
          ) {
            this.unregisterDevice(tokens[idx]);
          }
        }
      });

      return {
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses.map((resp) => ({
          success: resp.success,
          messageId: resp.messageId,
          error: resp.error?.message,
        })),
      };
    } catch (error) {
      const typedError = error as admin.FirebaseError;
      throw new Error(`Bulk send failed: ${typedError.message}`);
    }
  }
}
