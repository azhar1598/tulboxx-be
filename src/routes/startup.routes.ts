import { StartupController } from "../controllers/startup.controller";
import { Router } from "express";

const startupRouter = Router();
const startupController: any = new StartupController();

/**
 * @openapi
 * /startup:
 *   post:
 *     summary: Create a new startup
 *     description: Create a new startup
 *     tags:
 *       - Startup
 *     responses:
 *       200:
 *         description: A new startup
 */
startupRouter.post("/", (req: any, res: any) =>
  startupController.createStartup(req, res)
);

/**
 * @swagger
 * /:
 *   get:
 *     summary: Get all startups
 *     description: Get a list of all startups
 *     tags:
 *       - Startup
 *     responses:
 *       200:
 *         description: A list of startups
 */

startupRouter.get("/", (req: any, res: any) =>
  startupController.getStartups(req, res)
);

startupRouter.patch("/:id", (req: any, res: any) =>
  startupController.updateStartup(req, res)
);

startupRouter.delete("/:id", (req: any, res: any) =>
  startupController.deleteStartup(req, res)
);

startupRouter.get("/:id", (req: any, res: any) =>
  startupController.getStartupSingle(req, res)
);

startupRouter.get("/search", (req: any, res: any) =>
  startupController.searchStartups(req, res)
);

export default startupRouter;
