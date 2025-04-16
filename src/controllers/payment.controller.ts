import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";

// Define the schema for validation
const bankingSchema = z.object({
  accountHolderName: z.string().min(1, "Account holder name is required"),
  accountNumber: z.string().min(1, "Account number is required"),
  bankName: z.string().min(1, "Bank name is required"),
  branchCode: z.string().min(1, "Branch code is required"),
  routingNumber: z.string().min(1, "Routing number is required"),
  swiftCode: z.string().optional(),
  taxId: z.string().optional(),
});

export class PaymentController {
  async getPaymentInfo(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { data, error } = await supabase
        .from("payment_info")
        .select("*")
        .eq("user_id", user_id)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res
            .status(404)
            .json({ error: "Payment information not found" });
        }
        throw error;
      }

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching payment info:", error);
      return res
        .status(500)
        .json({ error: "Failed to fetch payment information" });
    }
  }

  async createPaymentInfo(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const validationResult = bankingSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const paymentData = validationResult.data;

      // Check if payment info already exists for this user
      const { data: existingPayment, error: checkError } = await supabase
        .from("payment_info")
        .select("id")
        .eq("user_id", user_id)
        .maybeSingle();

      if (checkError) throw checkError;

      if (existingPayment) {
        return res.status(409).json({
          error: "Payment information already exists",
          message:
            "You already have payment information set up. Please update instead.",
        });
      }

      const transformedPaymentData = {
        account_holder_name: paymentData.accountHolderName,
        account_number: paymentData.accountNumber,
        bank_name: paymentData.bankName,
        branch_code: paymentData.branchCode,
        routing_number: paymentData.routingNumber,
        swift_code: paymentData.swiftCode,
        tax_id: paymentData.taxId,
      };

      const dataToInsert = {
        ...transformedPaymentData,
        user_id,
        created_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("payment_info")
        .insert(dataToInsert)
        .select();

      if (error) throw error;

      return res.status(201).json({
        message: "Payment information created successfully",
        paymentInfo: data[0],
      });
    } catch (error: any) {
      console.error("Error creating payment info:", error);
      return res.status(500).json({
        error: "Failed to create payment information",
        details: error.message,
      });
    }
  }

  async updatePaymentInfo(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const validationResult = bankingSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const paymentData = validationResult.data;

      // First check if payment info exists and belongs to user
      const { data: existingPayment, error: fetchError } = await supabase
        .from("payment_info")
        .select("*")
        .eq("user_id", user_id)
        .single();

      if (fetchError) {
        if (fetchError.code === "PGRST116") {
          return res
            .status(404)
            .json({ error: "Payment information not found" });
        }
        throw fetchError;
      }

      const transformedPaymentData = {
        account_holder_name: paymentData.accountHolderName,
        account_number: paymentData.accountNumber,
        bank_name: paymentData.bankName,
        branch_code: paymentData.branchCode,
        routing_number: paymentData.routingNumber,
        swift_code: paymentData.swiftCode,
        tax_id: paymentData.taxId,
      };

      const dataToUpdate = {
        ...transformedPaymentData,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("payment_info")
        .update(dataToUpdate)
        .eq("user_id", user_id)
        .select();

      if (error) throw error;

      return res.status(200).json({
        message: "Payment information updated successfully",
        paymentInfo: data[0],
      });
    } catch (error: any) {
      console.error("Error updating payment info:", error);
      return res.status(500).json({
        error: "Failed to update payment information",
        details: error.message,
      });
    }
  }

  async deletePaymentInfo(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // First check if payment info exists and belongs to user
      const { data: existingPayment, error: fetchError } = await supabase
        .from("payment_info")
        .select("*")
        .eq("user_id", user_id)
        .single();

      if (fetchError) {
        if (fetchError.code === "PGRST116") {
          return res
            .status(404)
            .json({ error: "Payment information not found" });
        }
        throw fetchError;
      }

      const { error } = await supabase
        .from("payment_info")
        .delete()
        .eq("user_id", user_id);

      if (error) throw error;

      return res.status(200).json({
        message: "Payment information deleted successfully",
      });
    } catch (error: any) {
      console.error("Error deleting payment info:", error);
      return res.status(500).json({
        error: "Failed to delete payment information",
        details: error.message,
      });
    }
  }
}
