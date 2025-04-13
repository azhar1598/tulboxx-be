import { Router } from "express";
import { ClientController } from "../controllers/client.controller";

const clientRouter = Router();
const clientController: any = new ClientController();

clientRouter.get("/", clientController.getClients);
clientRouter.get("/:id", clientController.getClientById);
clientRouter.post("/", clientController.createClient);
clientRouter.put("/:id", clientController.updateClient);
clientRouter.delete("/:id", clientController.deleteClient);

export default clientRouter;
