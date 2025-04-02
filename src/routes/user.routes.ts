import { Router } from "express";
import { UserController } from "../controllers/user.controller";

const userProfileRouter = Router();
const userController = new UserController();

userProfileRouter.get("/:id", async (req, res) => {
  await userController.getUserProfile(req, res);
});

/**
 * @swagger
 * /auth/register:
 *   post:
 *     summary: User registration
 *     description: Register a new user with email and password
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *               name:
 *                 type: string
 */

export default userProfileRouter;
