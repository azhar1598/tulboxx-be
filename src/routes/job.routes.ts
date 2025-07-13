import { Router } from "express";
import { JobController } from "../controllers/job.controller";

const jobRouter = Router();
const jobController: any = new JobController();

jobRouter.get("/", jobController.getJobs);
jobRouter.get("/:id", jobController.getJobById);
jobRouter.post("/", jobController.createJob);
jobRouter.put("/:id", jobController.updateJob);
jobRouter.delete("/:id", jobController.deleteJob);

export default jobRouter;
