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
  user_id: z.string(),
});

export class EstimatesController {
  // async getEstimates(req: Request, res: Response) {
  //   try {
  //     // Extract pagination parameters from query
  //     const page = parseInt(req.query.page as string) || 1;
  //     const limit = parseInt(req.query.pageSize as string) || 10;
  //     const startIndex = (page - 1) * limit;

  //     // Extract filter parameters
  //     const filterId = req.query["filter.id"] as string | undefined;
  //     const search = req.query["search"] as string | undefined;

  //     // Build the query with filtering
  //     let query = supabase
  //       .from("estimates")
  //       .select("*", { count: "exact", head: true });

  //     if (filterId) {
  //       query = query.eq("id", filterId);
  //     }

  //     const { count, error: countError } = await query;
  //     if (countError) throw countError;

  //     // Fetch paginated data with filter
  //     let dataQuery = supabase
  //       .from("estimates")
  //       .select("*")
  //       .range(startIndex, startIndex + limit - 1);

  //     if (filterId) {
  //       dataQuery = dataQuery.eq("id", filterId);
  //     }

  //     if (search) {
  //       dataQuery = dataQuery.ilike("projectName", `%${search}%`);
  //     }

  //     const { data, error } = await dataQuery;
  //     if (error) throw error;

  //     // Calculate pagination metadata
  //     const totalRecords = count || 0;
  //     const totalPages = Math.ceil(totalRecords / limit);

  //     // Prepare the response with data and metadata
  //     const response = {
  //       data,
  //       metadata: {
  //         totalRecords,
  //         recordsPerPage: limit,
  //         currentPage: page,
  //         totalPages,
  //         hasNextPage: page < totalPages,
  //         hasPreviousPage: page > 1,
  //       },
  //     };

  //     return res.status(200).json(response);
  //   } catch (error) {
  //     console.error("Error fetching estimates:", error);
  //     return res.status(500).json({ error: "Failed to fetch estimates" });
  //   }
  // }

  async getEstimates(req: Request, res: Response) {
    try {
      // Extract pagination parameters from query
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.pageSize as string) || 10;
      const startIndex = (page - 1) * limit;

      // Extract filter parameters
      const filterId = req.query["filter.id"] as string | undefined;
      const search = req.query["search"] as string | undefined;

      console.log("req.user.id", req.user, req);

      // Get authenticated user ID (modify this based on your auth setup)
      const user_id = req.user?.id; // Ensure this is available from your auth middleware
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Build the query with filtering
      let query = supabase
        .from("estimates")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user_id); // Filter estimates by authenticated user ID

      if (filterId) {
        query = query.eq("id", filterId);
      }

      const { count, error: countError } = await query;
      if (countError) throw countError;

      // Fetch paginated data with filter
      let dataQuery = supabase
        .from("estimates")
        .select("*")
        .eq("user_id", user_id) // Ensure only the user’s estimates are fetched
        .range(startIndex, startIndex + limit - 1);

      if (filterId) {
        dataQuery = dataQuery.eq("id", filterId);
      }

      if (search) {
        dataQuery = dataQuery.ilike("projectName", `%${search}%`);
      }

      const { data, error } = await dataQuery;
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
        user_id: estimateData.user_id,
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

  // async deleteEstimate(req: Request, res: Response) {
  //   try {
  //     const { id } = req.params; // Get the estimate ID from URL params

  //     if (!id) {
  //       return res.status(400).json({ error: "Estimate ID is required" });
  //     }

  //     // Check if the estimate exists before deleting
  //     const { data: existingEstimate, error: checkError } = await supabase
  //       .from("estimates")
  //       .select("id")
  //       .eq("id", id)
  //       .single();

  //     if (checkError || !existingEstimate) {
  //       console.log("Estimate not found:", id);
  //       return res.status(404).json({ error: "Estimate not found" });
  //     }

  //     // Attempt to delete the estimate
  //     const { data, error: deleteError } = await supabase
  //       .from("estimates")
  //       .delete()
  //       .eq("id", id)
  //       .select(); // Add .select() to return deleted rows

  //     if (deleteError) {
  //       console.error("Delete error:", deleteError);
  //       return res
  //         .status(500)
  //         .json({ error: "Failed to delete estimate", details: deleteError });
  //     }

  //     console.log("Deleted estimate:", data);
  //     return res.status(200).json({
  //       success: true,
  //       message: "Estimate deleted successfully",
  //       deletedId: id,
  //     });
  //   } catch (error) {
  //     console.error("Error deleting estimate:", error);
  //     return res.status(500).json({ error: "Failed to delete estimate" });
  //   }
  // }

  async deleteEstimate(req: Request, res: Response) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({ error: "Estimate ID is required" });
      }

      // First, delete related invoices
      const { error: invoiceDeleteError } = await supabase
        .from("invoices")
        .delete()
        .eq("estimate_id", id); // Change this to the correct foreign key column

      if (invoiceDeleteError) {
        throw invoiceDeleteError;
      }

      // Now, delete the estimate
      const { data, error: deleteError } = await supabase
        .from("estimates")
        .delete()
        .eq("id", id)
        .select();

      if (deleteError) {
        throw deleteError;
      }

      return res.status(200).json({
        success: true,
        message: "Estimate and related invoices deleted successfully",
        deletedId: id,
      });
    } catch (error) {
      console.error("Error deleting estimate:", error);
      return res.status(500).json({ error: "Failed to delete estimate" });
    }
  }
}
