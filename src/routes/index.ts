import { Router } from "express";
import businessRouter from "./business.routes";
import { authMiddleware } from "../middlewares/auth";
import notificationRouter from "./notification.routes";
import startupRouter from "./startup.routes";

import startupPublicRouter from "./public/startup.routes";
import jobRouter from "./job.routes";
import jobPublicRouter from "./public/jobs.routes";
import estimatePublicRouter from "./public/estimates.routes";
import estimatesRouter from "./estimates.routes";
import invoicesRouter from "./invoices.routes";
import contentRouter from "./content.routes";
import authRouter from "./auth.routes";
import userProfileRouter from "./user.routes";
import clientRouter from "./client.routes";
import paymentRouter from "./payment.routes";

const routes = Router();

// routes.use(authMiddleware);

routes.use("/startup", authMiddleware, startupRouter);
routes.use("/business-insights", authMiddleware, businessRouter);
routes.use("/notifications", authMiddleware, notificationRouter);
routes.use("/job", authMiddleware, jobRouter);
routes.use("/estimates", authMiddleware, estimatesRouter);
routes.use("/invoices", authMiddleware, invoicesRouter);
routes.use("/content", authMiddleware, contentRouter);
routes.use("/user-profile", authMiddleware, userProfileRouter);
routes.use("/clients", authMiddleware, clientRouter);
routes.use("/jobs", authMiddleware, jobRouter);
routes.use("/payment-info", authMiddleware, paymentRouter);

const publicRoutes = Router();
const authRoutes = Router();

// Authentication routes (login, register, etc.)
authRoutes.use("/", authRouter);
// public routes
publicRoutes.use("/startup", startupPublicRouter);
publicRoutes.use("/job", jobPublicRouter);

/**
 * @swagger
 * /public/estimates:
 *   get:
 *     summary: Get public estimates
 *     description: Get a list of public estimates
 */
publicRoutes.use("/estimates", estimatePublicRouter);

export { routes as protectedRoutes, publicRoutes, authRoutes };
