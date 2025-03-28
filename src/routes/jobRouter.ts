import { Router, Request, Response } from "express";
import { JobController } from "../controllers/job.controller";

const jobRouter = Router();
const jobController: any = new JobController();

jobRouter.post("/", (req: any, res: any) => jobController.createJob(req, res));
export default jobRouter;
