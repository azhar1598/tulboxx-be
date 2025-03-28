import { Router, Request, Response } from "express";

import { AuthController } from "../controllers/auth.controller";

const authRouter = Router();
const authController: any = new AuthController();

authRouter.post("/login", (req: any, res: any) =>
  authController.login(req, res)
);

// authRouter.get("/callback", (req: any, res: any) =>
//   authController.callback(req, res)
// );
export default authRouter;
