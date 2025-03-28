import { StartupPublicController } from "../../controllers/public/startup.controller";
import { Router } from "express";

const startupPublicRouter = Router();
const startupPublicController: any = new StartupPublicController();

startupPublicRouter.get("/", (req: any, res: any) =>
  startupPublicController.getPublicStartups(req, res)
);

export default startupPublicRouter;
