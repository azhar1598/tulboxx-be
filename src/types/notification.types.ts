export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface SendNotificationResponse {
  success: boolean;
  messageId?: string;
  error?: string;
}

export interface BulkNotificationResponse {
  successCount: number;
  failureCount: number;
  responses: SendNotificationResponse[];
}
