import swaggerJSDoc from "swagger-jsdoc";
import { Router } from "express";
import { ContentController } from "../controllers/content.controller";

const contentRouter = Router();
const contentController: any = new ContentController();

contentRouter.get("/", contentController.getContents);

contentRouter.post("/", contentController.createContent);

contentRouter.get("/:id", contentController.getContentById);

contentRouter.put("/:id", contentController.updateContent);

contentRouter.delete("/:id", contentController.deleteContent);

contentRouter.get("/project/:id", contentController.getContentsByProjectId);

export default contentRouter;
