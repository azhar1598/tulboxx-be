import { Router, Request, Response } from "express";
import { BusinessController } from "../controllers/business.controller";

const businessRouter = Router();
const businessController: any = new BusinessController();

businessRouter.get("/", (req: any, res: any) =>
  businessController.getBusinessInsights(req, res)
);
export default businessRouter;
