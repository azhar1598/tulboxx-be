import swaggerJSDoc from "swagger-jsdoc";
import { EstimatePublicController } from "../../controllers/public/estimates.controller";
import { Router } from "express";

const estimatePublicRouter = Router();
const estimatePublicController: any = new EstimatePublicController();

/**
 * @openapi
 * /public/estimates:
 *   get:
 *     summary: Get public estimates
 *     description: Get a list of public estimates
 *     tags:
 *       - Estimates
 *     responses:
 *       200:
 *         description: A list of public estimates
 *         content:
 */

/**
 * @openapi
 * /public/estimates:
 *   get:
 *     summary: Get public estimates
 *     description: Get a list of public estimates
 */
// estimatePublicRouter.get("/", (req: any, res: any) =>
//   estimatePublicController.getPublicEstimates(req, res)
// );

estimatePublicRouter.get("/", estimatePublicController.getPublicEstimates);

/**
 * @openapi
 * /public/estimates:
 *   post:
 *     summary: Create a new estimate
 *     description: Create a new estimate
 */
estimatePublicRouter.post("/", estimatePublicController.createEstimate);

export default estimatePublicRouter;
