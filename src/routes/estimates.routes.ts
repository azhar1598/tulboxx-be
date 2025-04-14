import swaggerJSDoc from "swagger-jsdoc";
import { EstimatesController } from "../controllers/estimates.controller";
import { Router } from "express";

const estimatesRouter = Router();
const estimatesController: any = new EstimatesController();

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
 * /estimates:
 *   get:
 *     summary: Get public estimates
 *     description: Get a list of public estimates
 */
// estimatePublicRouter.get("/", (req: any, res: any) =>
//   estimatePublicController.getPublicEstimates(req, res)
// );

estimatesRouter.get("/", estimatesController.getEstimates);

/**
 * @openapi
 * /estimates:
 *   post:
 *     summary: Create a new estimate
 *     description: Create a new estimate
 */
estimatesRouter.post("/", estimatesController.createEstimate);

/**
 * @openapi
 * /estimates/{id}:
 *   get:
 *     summary: Get estimate by id
 *     description: Get an estimate by id
 */
estimatesRouter.get("/:id", estimatesController.getEstimateById);

/**
 * @openapi
 * /estimates/{id}:
 *   delete:
 *     summary: Delete an estimate by id
 *     description: Delete an estimate by id
 */
estimatesRouter.delete("/:id", estimatesController.deleteEstimate);

/**
 * @openapi
 * /estimates/{id}:
 *   patch:
 *     summary: Update an estimate by id
 *     description: Update an estimate by id
 */
estimatesRouter.patch("/:id", estimatesController.updateEstimate);

export default estimatesRouter;
