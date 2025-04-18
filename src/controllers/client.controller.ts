import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";

// Define the schema for validation
const clientSchema = z.object({
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Invalid email address"),
  phone: z.number().min(10, "Phone number is required"),
  address: z.string().min(1, "Address is required"),
  user_id: z.string(),
});

export class ClientController {
  async getClients(req: Request, res: Response) {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 10;
      const filterId = req.query["filter.id"] as string | undefined;
      const search = req.query["search"] as string | undefined;

      // Get authenticated user ID
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Build the query with filtering
      let query = supabase
        .from("clients")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user_id);

      if (filterId) {
        query = query.eq("id", filterId);
      }

      // Get total count of records
      const { count, error: countError } = await query;
      if (countError) throw countError;

      // Fetch data with or without pagination
      let dataQuery = supabase
        .from("clients")
        .select("*")
        .eq("user_id", user_id);

      if (limit !== -1) {
        const startIndex = (page - 1) * limit;
        dataQuery = dataQuery.range(startIndex, startIndex + limit - 1);
      }

      if (filterId) {
        dataQuery = dataQuery.eq("id", filterId);
      }

      if (search) {
        dataQuery = dataQuery.ilike("name", `%${search}%`);
      }

      const { data, error } = await dataQuery;
      if (error) throw error;

      // Calculate pagination metadata only if pagination is enabled
      const response: any = { data };

      if (limit !== -1) {
        const totalRecords = count || 0;
        const totalPages = Math.ceil(totalRecords / limit);

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
      console.error("Error fetching clients:", error);
      return res.status(500).json({ error: "Failed to fetch clients" });
    }
  }

  async createClient(req: Request, res: Response) {
    try {
      const validationResult = clientSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
          message: "Please check your input and try again.",
        });
      }

      const clientData = validationResult.data;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({
          error: "Unauthorized",
          message: "You must be logged in to perform this action.",
        });
      }

      // Check if email already exists for this user
      const { data: existingEmailClient, error: emailCheckError } =
        await supabase
          .from("clients")
          .select("id")
          .eq("email", clientData.email)
          .eq("user_id", user_id)
          .maybeSingle();

      if (emailCheckError) throw emailCheckError;

      if (existingEmailClient) {
        return res.status(409).json({
          error: "Validation failed",
          details: { email: ["Email address already in use"] },
          message: `A client with the email address "${clientData.email}" already exists in your account.`,
        });
      }

      // Check if phone already exists for this user
      const { data: existingPhoneClient, error: phoneCheckError } =
        await supabase
          .from("clients")
          .select("id")
          .eq("phone", clientData.phone)
          .eq("user_id", user_id)
          .maybeSingle();

      if (phoneCheckError) throw phoneCheckError;

      if (existingPhoneClient) {
        return res.status(409).json({
          error: "Validation failed",
          details: { phone: ["Phone number already in use"] },
          message: `A client with the phone number "${clientData.phone}" already exists in your account.`,
        });
      }

      const dataToInsert = {
        name: clientData.name,
        email: clientData.email,
        phone: clientData.phone,
        address: clientData.address,
        user_id: user_id,
        created_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("clients")
        .insert(dataToInsert)
        .select();

      if (error) {
        // Handle specific database constraint errors
        if (error.code === "23505") {
          // PostgreSQL unique violation code
          if (error.message.includes("email")) {
            return res.status(409).json({
              error: "Validation failed",
              details: { email: ["Email address already in use"] },
              message: `A client with the email address "${clientData.email}" already exists in your account.`,
            });
          } else if (error.message.includes("phone")) {
            return res.status(409).json({
              error: "Validation failed",
              details: { phone: ["Phone number already in use"] },
              message: `A client with the phone number "${clientData.phone}" already exists in your account.`,
            });
          }
        }
        throw error;
      }

      return res.status(201).json({
        message: "Client created successfully",
        client: data[0],
      });
    } catch (error: any) {
      console.error("Error creating client:", error);
      return res.status(500).json({
        error: "Failed to create client",
        details: error.message,
        message:
          "An unexpected error occurred while creating the client. Please try again later.",
      });
    }
  }

  async getClientById(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { data, error } = await supabase
        .from("clients")
        .select("*")
        .eq("id", id)
        .eq("user_id", user_id)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "Client not found" });
        }
        throw error;
      }

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching client:", error);
      return res.status(500).json({ error: "Failed to fetch client" });
    }
  }

  async updateClient(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // First check if client exists and belongs to user
      const { data: existingClient, error: fetchError } = await supabase
        .from("clients")
        .select("*")
        .eq("id", id)
        .eq("user_id", user_id)
        .single();

      if (fetchError) {
        if (fetchError.code === "PGRST116") {
          return res.status(404).json({ error: "Client not found" });
        }
        throw fetchError;
      }

      const validationResult = clientSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const clientData = validationResult.data;

      // Update in database
      const { data, error } = await supabase
        .from("clients")
        .update({
          name: clientData.name,
          email: clientData.email,
          phone: clientData.phone,
          address: clientData.address,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id)
        .eq("user_id", user_id)
        .select();

      if (error) throw error;

      return res.status(200).json({
        message: "Client updated successfully",
        client: data[0],
      });
    } catch (error: any) {
      console.error("Error updating client:", error);
      return res.status(500).json({
        error: "Failed to update client",
        details: error.message,
      });
    }
  }

  async deleteClient(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // First check if client exists and belongs to user
      const { data: existingClient, error: fetchError } = await supabase
        .from("clients")
        .select("*")
        .eq("id", id)
        .eq("user_id", user_id)
        .single();

      if (fetchError) {
        if (fetchError.code === "PGRST116") {
          return res.status(404).json({ error: "Client not found" });
        }
        throw fetchError;
      }

      const { error } = await supabase
        .from("clients")
        .delete()
        .eq("id", id)
        .eq("user_id", user_id);

      if (error) throw error;

      return res.status(200).json({
        message: "Client deleted successfully",
      });
    } catch (error: any) {
      console.error("Error deleting client:", error);
      return res.status(500).json({
        error: "Failed to delete client",
        details: error.message,
      });
    }
  }
}
