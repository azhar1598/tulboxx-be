import { Request, Response } from "express";
import { supabase } from "../../supabaseClient";
import { z } from "zod";

// Define the schema for validation
const lineItemSchema = z.object({
  id: z.number(),
  description: z.string(),
  quantity: z.number(),
  unitPrice: z.number(),
  totalPrice: z.number(),
});

const estimationSchema = z.object({
  // General form
  projectName: z.string().min(1, "Project name is required"),
  customerName: z.string().min(1, "Customer name is required"),
  email: z.string().email("Invalid email format"),
  phone: z.string(),
  address: z.string(),
  type: z.enum(["residential", "commercial"]),

  // Project form
  serviceType: z.string(),
  problemDescription: z.string(),
  solutionDescription: z.string(),
  projectEstimate: z.string(),
  projectStartDate: z.string(),
  projectEndDate: z.string(),
  lineItems: z.array(lineItemSchema),

  // Additional fields
  equipmentMaterials: z.string(),
  additionalNotes: z.string(),
});

export class EstimatePublicController {
  async getPublicEstimates(req: Request, res: Response) {
    try {
      const { data, error } = await supabase.from("estimates").select("*");

      if (error) throw error;

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching estimates:", error);
      return res.status(500).json({ error: "Failed to fetch estimates" });
    }
  }

  async createEstimate(req: Request, res: Response) {
    try {
      const validationResult = estimationSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const estimateData = validationResult.data;

      // Calculate total amount from line items
      const totalAmount = estimateData.lineItems.reduce(
        (sum, item) => sum + item.totalPrice,
        0
      );

      // Add metadata
      const dataToInsert = {
        ...estimateData,
        total_amount: totalAmount,
        created_at: new Date().toISOString(),
        status: "pending",
      };

      // Insert into database
      const { data, error } = await supabase
        .from("estimates")
        .insert(dataToInsert)
        .select();

      if (error) throw error;

      return res.status(201).json({
        message: "Estimate created successfully",
        estimate: data[0],
      });
    } catch (error: any) {
      console.error("Error creating estimate:", error);
      return res.status(500).json({
        error: "Failed to create estimate",
        details: error.message,
      });
    }
  }

  async getEstimateById(req: Request, res: Response) {
    try {
      const { id } = req.params;

      const { data, error } = await supabase
        .from("estimates")
        .select("*")
        .eq("id", id)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "Estimate not found" });
        }
        throw error;
      }

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching estimate:", error);
      return res.status(500).json({ error: "Failed to fetch estimate" });
    }
  }
}
