import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";
import { generateEstimateWithGemini } from "../utils/aiService";

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
  phone: z.number(),
  address: z.string(),
  type: z.enum(["residential", "commercial"]),

  // Project form
  serviceType: z.string(),
  problemDescription: z.string(),
  solutionDescription: z.string(),
  projectEstimate: z.number(),
  projectStartDate: z.string(),
  projectEndDate: z.string(),
  lineItems: z.array(lineItemSchema),

  // Additional fields
  equipmentMaterials: z.string(),
  additionalNotes: z.string(),
});

export class EstimatesController {
  async getEstimates(req: Request, res: Response) {
    try {
      // Extract pagination parameters from query
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;
      const startIndex = (page - 1) * limit;

      // First, get the total count of records
      const { count, error: countError } = await supabase
        .from("estimates")
        .select("*", { count: "exact", head: true });

      if (countError) throw countError;

      // Then fetch the paginated data
      const { data, error } = await supabase
        .from("estimates")
        .select("*")
        .range(startIndex, startIndex + limit - 1);

      if (error) throw error;

      // Calculate pagination metadata
      const totalRecords = count || 0;
      const totalPages = Math.ceil(totalRecords / limit);

      // Prepare the response with data and metadata
      const response = {
        data,
        metadata: {
          totalRecords,
          recordsPerPage: limit,
          currentPage: page,
          totalPages,
          hasNextPage: page < totalPages,
          hasPreviousPage: page > 1,
        },
      };

      return res.status(200).json(response);
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

      let generatedEstimate;
      try {
        generatedEstimate = await generateEstimateWithGemini(estimateData);
      } catch (apiError: any) {
        console.error("Gemini API error:", apiError);
        return res.status(500).json({
          error: "Failed to generate content with AI",
          details: apiError.message,
        });
      }

      // Calculate total amount from line items
      const totalAmount = estimateData.lineItems.reduce(
        (sum, item) => sum + item.totalPrice,
        0
      );

      // Add metadata
      const dataToInsert = {
        ...estimateData,
        ai_generated_estimate: generatedEstimate,
        total_amount: totalAmount,
        created_at: new Date().toISOString(),
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
