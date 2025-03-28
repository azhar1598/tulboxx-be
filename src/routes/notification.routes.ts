// import { Router, Request, Response } from "express";
// import { NotificationService } from "../services/notification.service";
// import { NotificationPayload } from "../types/notification.types";

// interface RegisterDeviceRequest {
//   token: string;
// }

// interface SendNotificationRequest extends NotificationPayload {
//   token: string;
// }

// export class NotificationController {
//   private router: Router;
//   private notificationService: NotificationService;

//   constructor(notificationService: NotificationService) {
//     this.router = Router();
//     this.notificationService = notificationService;
//     this.initializeRoutes();
//   }

//   private initializeRoutes(): void {
//     this.router.post("/register-device", this.registerDevice.bind(this));
//     this.router.post("/send-notification", this.sendNotification.bind(this));
//     this.router.post(
//       "/broadcast-notification",
//       this.broadcastNotification.bind(this)
//     );
//   }

//   private async registerDevice(
//     req: Request<{}, {}, RegisterDeviceRequest>,
//     res: Response
//   ): Promise<Response> {
//     try {
//       const { token } = req.body;

//       if (!token) {
//         return res.status(400).json({
//           success: false,
//           error: "Token is required",
//         });
//       }

//       await this.notificationService.registerDevice(token);

//       return res.json({
//         success: true,
//         message: "Device registered successfully",
//       });
//     } catch (error) {
//       const typedError = error as Error;
//       return res.status(400).json({
//         success: false,
//         error: typedError.message,
//       });
//     }
//   }

//   private async sendNotification(
//     req: Request<{}, {}, SendNotificationRequest>,
//     res: Response
//   ): Promise<Response> {
//     try {
//       const { token, title, body, data } = req.body;

//       if (!token || !title || !body) {
//         return res.status(400).json({
//           success: false,
//           error: "Token, title, and body are required",
//         });
//       }

//       const response = await this.notificationService.sendToDevice(token, {
//         title,
//         body,
//         data,
//       });

//       return res.json(response);
//     } catch (error) {
//       const typedError = error as Error;
//       return res.status(500).json({
//         success: false,
//         error: typedError.message,
//       });
//     }
//   }

//   private async broadcastNotification(
//     req: Request<{}, {}, NotificationPayload>,
//     res: Response
//   ): Promise<Response> {
//     try {
//       const { title, body, data } = req.body;

//       if (!title || !body) {
//         return res.status(400).json({
//           success: false,
//           error: "Title and body are required",
//         });
//       }

//       const response = await this.notificationService.sendToMultipleDevices({
//         title,
//         body,
//         data,
//       });

//       return res.json(response);
//     } catch (error) {
//       const typedError = error as Error;
//       return res.status(500).json({
//         success: false,
//         error: typedError.message,
//       });
//     }
//   }

//   public getRouter(): Router {
//     return this.router;
//   }
// }

import { Router, Request, Response } from "express";
import { BusinessController } from "../controllers/business.controller";

const notificationRouter = Router();
const notificationController: any = new BusinessController();

notificationRouter.get("/business-insights", (req: any, res: any) =>
  notificationController.getBusinessInsights(req, res)
);
export default notificationRouter;
