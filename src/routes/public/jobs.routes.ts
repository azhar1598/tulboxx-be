import { JobPublicController } from "../../controllers/public/job.controller";
import { Router } from "express";

const jobPublicRouter = Router();
const jobPublicController: any = new JobPublicController();

jobPublicRouter.get("/:startup_id", (req: any, res: any) =>
  jobPublicController.getPublicJobs(req, res)
);

export default jobPublicRouter;
