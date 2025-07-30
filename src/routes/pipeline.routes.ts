import { Router } from "express";
import { PipelineController } from "../controllers/pipeline.controller";

const pipelineRouter = Router();
const pipelineController: any = new PipelineController();

// clientRouter.get("/", clientController.getClients);
// clientRouter.get("/:id", clientController.getClientById);
// clientRouter.post("/", clientController.createClient);
// clientRouter.put("/:id", clientController.updateClient);
// clientRouter.delete("/:id", clientController.deleteClient);

pipelineRouter.get("/stages", pipelineController.getStages);
pipelineRouter.post("/stages", pipelineController.createStage);
pipelineRouter.put("/stages/:id", pipelineController.updateStage);
pipelineRouter.delete("/stages/:id", pipelineController.deleteStage);

// Lead routes
pipelineRouter.get("/leads", pipelineController.getLeads);
pipelineRouter.post("/leads", pipelineController.createLead);
pipelineRouter.get("/leads/:id", pipelineController.getLeadById);
pipelineRouter.patch("/leads/:id", pipelineController.updateLead);
pipelineRouter.delete("/leads/:id", pipelineController.deleteLead);

export default pipelineRouter;
