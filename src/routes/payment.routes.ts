import { Router } from "express";
import { PaymentController } from "../controllers/payment.controller";

const paymentRouter = Router();
const paymentController: any = new PaymentController();

paymentRouter.get("/", paymentController.getPaymentInfo);
paymentRouter.post("/", paymentController.createPaymentInfo);
paymentRouter.patch("/", paymentController.updatePaymentInfo);
paymentRouter.delete("/", paymentController.deletePaymentInfo);

export default paymentRouter;
