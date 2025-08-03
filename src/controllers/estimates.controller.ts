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

const comprehensiveEstimationSchema = z.object({
  // General form
  projectName: z.string().min(1, "Project name is required"),
  clientId: z.string().min(1, "Client is required"),
  name: z.string().optional(),

  // Project form
  serviceType: z.string(),
  problemDescription: z.string(),
  solutionDescription: z.string(),
  projectEstimate: z.number(),
  projectStartDate: z.string(),
  projectEndDate: z.string(),
  lineItems: z.array(lineItemSchema),
  projectType: z.enum(["residential", "commercial"]), // Changed from project_type

  // Additional fields
  equipmentMaterials: z.string(),
  additionalNotes: z.string(),
  ai_generated_estimate: z.string().optional(),
});

const quickEstimateSchema = z.object({
  projectName: z.string().min(1, "Project name is required"),
  projectEstimate: z.coerce.number().min(1, "Project estimate is required"),
  clientId: z.string().min(1, "Client is required"),
  additionalNotes: z.string().optional(),
  name: z.string().optional(),
  projectType: z.enum(["residential", "commercial"]), // Changed from project_type
});

const estimateSchema = z.union([
  comprehensiveEstimationSchema,
  quickEstimateSchema,
]);

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
      const limit = parseInt(req.query.limit as string) || 10;

      // Extract filter and sort parameters
      const filterId = req.query["filter.id"] as string | undefined;
      const search = req.query["search"] as string | undefined;
      const sortBy = req.query.sortBy as string[] | string | undefined;

      let sortColumn = "created_at";
      let sortDirection = "desc";

      const allowedSortColumns = [
        "projectName",
        "type",
        "total_amount",
        "created_at",
        "projectStartDate",
        "projectEndDate",
      ];

      if (sortBy) {
        const sortParam = Array.isArray(sortBy) ? sortBy[0] : sortBy;
        const [column, direction] = sortParam.split(":");
        if (
          column &&
          allowedSortColumns.includes(column) &&
          direction &&
          (direction.toUpperCase() === "ASC" ||
            direction.toUpperCase() === "DESC")
        ) {
          sortColumn = column;
          sortDirection = direction.toLowerCase();
        }
      }

      // Get authenticated user ID
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Use RPC to fetch estimates
      const { data, error: rpcError } = await supabase.rpc("search_estimates", {
        user_id_arg: user_id,
        search_term: search || null,
        filter_id_arg: filterId || null,
        page_num: page,
        page_size: limit,
        sort_column: sortColumn,
        sort_direction: sortDirection,
      });

      if (rpcError) {
        console.error("Error fetching estimates via RPC:", rpcError);
        throw rpcError;
      }

      const response: any = { data };

      if (limit !== -1) {
        // Use RPC to fetch the total count
        const { data: countData, error: countError } = await supabase.rpc(
          "search_estimates_count",
          {
            user_id_arg: user_id,
            search_term: search || null,
            filter_id_arg: filterId || null,
          }
        );

        if (countError) {
          console.error("Error fetching estimates count via RPC:", countError);
          throw countError;
        }
        const count = countData;

        // Calculate pagination metadata
        const totalRecords = count || 0;
        const totalPages = Math.ceil(totalRecords / limit);

        // Prepare the response
        response.metadata = {
          totalRecords,
          recordsPerPage: limit,
          currentPage: page,
          totalPages,
          hasNextPage: page < totalPages,
          hasPreviousPage: page > 1,
        };
      }

      return res.status(200).json(response);
    } catch (error) {
      console.error("Error fetching estimates:", error);
      return res.status(500).json({ error: "Failed to fetch estimates" });
    }
  }

  // async createEstimate(req: Request, res: Response) {
  //   try {
  //     const validationResult = estimationSchema.safeParse(req.body);

  //     if (!validationResult.success) {
  //       return res.status(400).json({
  //         error: "Validation failed",
  //         details: validationResult.error.format(),
  //       });
  //     }

  //     const estimateData = validationResult.data;

  //     let generatedEstimate;
  //     try {
  //       generatedEstimate = await generateEstimateWithGemini(estimateData);
  //     } catch (apiError: any) {
  //       console.error("Gemini API error:", apiError);
  //       return res.status(500).json({
  //         error: "Failed to generate content with AI",
  //         details: apiError.message,
  //       });
  //     }

  //     // Calculate total amount from line items
  //     const totalAmount = estimateData.lineItems.reduce(
  //       (sum, item) => sum + item.totalPrice,
  //       0
  //     );

  //     // Add metadata
  //     const dataToInsert = {
  //       ...estimateData,
  //       ai_generated_estimate: generatedEstimate,
  //       total_amount: totalAmount,
  //       user_id: estimateData.user_id,
  //       created_at: new Date().toISOString(),
  //     };

  //     // Insert into database
  //     const { data, error } = await supabase
  //       .from("estimates")
  //       .insert(dataToInsert)
  //       .select();

  //     if (error) throw error;

  //     return res.status(201).json({
  //       message: "Estimate created successfully",
  //       estimate: data[0],
  //     });
  //   } catch (error: any) {
  //     console.error("Error creating estimate:", error);
  //     return res.status(500).json({
  //       error: "Failed to create estimate",
  //       details: error.message,
  //     });
  //   }
  // }

  async createEstimate(req: Request, res: Response) {
    try {
      const type = req.query.type as string;
      const validationSchema =
        type === "quick" ? quickEstimateSchema : comprehensiveEstimationSchema;

      const validationResult = validationSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const estimateData = validationResult.data;

      // Map projectType to project_type
      const project_type = req.body.projectType;

      // Verify that the client exists before proceeding
      const { data: clientData, error: clientError } = await supabase
        .from("clients")
        .select("id")
        .eq("id", estimateData.clientId) // Using clientId as received from frontend
        .single();

      if (clientError || !clientData) {
        return res.status(400).json({
          error: "Invalid client ID",
          details: "The specified client does not exist",
        });
      }

      // Transform the data for database insertion - convert clientId to client_id
      const { clientId, projectType, ...otherData } = estimateData;

      let dataToInsert;

      if (type === "quick") {
        const { projectEstimate, ...restOfQuickData } = otherData as Omit<
          z.infer<typeof quickEstimateSchema>,
          "clientId" | "projectType"
        >;

        dataToInsert = {
          ...restOfQuickData,
          client_id: clientId,
          total_amount: projectEstimate,
          user_id: req.user?.id,
          created_at: new Date().toISOString(),
          project_type: projectType, // Map projectType to project_type
        };
      } else {
        const comprehensiveData = otherData as Omit<
          z.infer<typeof comprehensiveEstimationSchema>,
          "clientId" | "projectType"
        >;

        let generatedEstimate;
        try {
          generatedEstimate = await generateEstimateWithGemini(
            estimateData as any
          );
        } catch (apiError: any) {
          console.error("Gemini API error:", apiError);
          return res.status(500).json({
            error: "Failed to generate content with AI",
            details: apiError.message,
          });
        }

        // Calculate total amount from line items
        const totalAmount = comprehensiveData.lineItems.reduce(
          (sum, item) => sum + item.totalPrice,
          0
        );

        // Add metadata with the correct field name for the database
        dataToInsert = {
          ...comprehensiveData,
          client_id: clientId, // Convert from clientId to client_id
          ai_generated_estimate: generatedEstimate,
          total_amount: totalAmount,
          user_id: req.user?.id,
          created_at: new Date().toISOString(),
          type: type || "comprehensive",
          project_type: projectType, // Map projectType to project_type
        };
      }

      // Insert into database
      const { data, error } = await supabase
        .from("estimates")
        .insert(dataToInsert)
        .select();

      if (error) {
        console.error("Database insertion error:", error);
        throw error;
      }

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
        .select(
          `
          *,
          clients:client_id (*)
        `
        )
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

  async updateEstimate(req: Request, res: Response) {
    try {
      const { id } = req.params;

      // Validate estimateId
      if (!id) {
        return res.status(400).json({
          error: "Missing estimate ID",
          details: "An estimate ID is required to update an estimate",
        });
      }

      // Check if the estimate exists
      const { data: existingEstimate, error: fetchError } = await supabase
        .from("estimates")
        .select("*")
        .eq("id", id)
        .single();

      if (fetchError || !existingEstimate) {
        return res.status(404).json({
          error: "Estimate not found",
          details: "The specified estimate does not exist",
        });
      }

      // Validate the request body
      const type = req.query.type as string;
      const validationSchema =
        type === "quick" ? quickEstimateSchema : comprehensiveEstimationSchema;
      const validationResult = validationSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const updateData = validationResult.data;

      // Map projectType to project_type
      const project_type = req.body.projectType;

      const { clientId, ...otherData } = updateData;
      let dataToUpdate;

      if (type === "quick") {
        const { projectEstimate, ...restOfQuickData } = otherData as Omit<
          z.infer<typeof quickEstimateSchema>,
          "clientId"
        >;

        dataToUpdate = {
          ...restOfQuickData,
          ...(clientId && { client_id: clientId }),
          total_amount: projectEstimate,
          updated_at: new Date().toISOString(),
          user_id: req.user?.id,
          type: "quick",
          project_type, // Use mapped project_type
        };
      } else {
        const comprehensiveData = otherData as Omit<
          z.infer<typeof comprehensiveEstimationSchema>,
          "clientId"
        >;

        let totalAmount = existingEstimate.total_amount;
        if (comprehensiveData.lineItems) {
          totalAmount = comprehensiveData.lineItems.reduce(
            (sum, item) => sum + item.totalPrice,
            0
          );
        }

        dataToUpdate = {
          ...comprehensiveData,
          ...(clientId && { client_id: clientId }),
          total_amount: totalAmount,
          updated_at: new Date().toISOString(),
          user_id: req.user?.id,
          type: type || "comprehensive",
          project_type, // Use mapped project_type
        };
      }

      // Update the estimate
      const { data, error } = await supabase
        .from("estimates")
        .update(dataToUpdate)
        .eq("id", id)
        .select();

      if (error) {
        console.error("Database update error:", error);
        throw error;
      }

      return res.status(200).json({
        message: "Estimate updated successfully",
        estimate: data[0],
      });
    } catch (error: any) {
      console.error("Error updating estimate:", error);
      return res.status(500).json({
        error: "Failed to update estimate",
        details: error.message,
      });
    }
  }
}