import swaggerJSDoc from "swagger-jsdoc";
import { InvoicesController } from "../controllers/invoices.controller";
import { Router } from "express";

const invoicesRouter = Router();
const invoicesController: any = new InvoicesController();

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

invoicesRouter.get("/", invoicesController.getInvoices);

/**
 * @openapi
 * /estimates:
 *   post:
 *     summary: Create a new estimate
 *     description: Create a new estimate
 */
invoicesRouter.post("/", invoicesController.createInvoice);

/**
 * @openapi
 * /estimates/{id}:
 *   get:
 *     summary: Get estimate by id
 *     description: Get an estimate by id
 */
invoicesRouter.get("/:id", invoicesController.getInvoiceById);

export default invoicesRouter;
