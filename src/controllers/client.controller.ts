import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";

// Define the schema for validation
const clientSchema = z.object({
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Invalid email address"),
  phone: z.number().min(10, "Phone number is required"),
  address: z.string().min(1, "Address is required"),
  city: z.string().min(1, "City is required"),
  state: z.string().min(1, "State is required"),
  zip: z.number().min(1, "Zip code is required"),
  notes: z.string().optional(),
});

export class ClientController {
  async getClients(req: Request, res: Response) {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 10;
      const filterId = req.query["filter.id"] as string | undefined;
      const search = req.query["search"] as string | undefined;
      const sortBy = req.query.sortBy as string[] | string | undefined;

      let sortColumn = "created_at";
      let sortDirection = "desc";

      const allowedSortColumns = [
        "name",
        "email",
        "phone",
        "address",
        "city",
        "state",
        "zip",
        "created_at",
      ];

      if (sortBy) {
        // Handle array format for sortBy, e.g., sortBy[]=name:ASC
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

      let data, count;

      // Use RPC when a search term is provided, even if empty.
      if (search || search === "") {
        const { data: rpcData, error } = await supabase.rpc(
          "search_clients_by_user",
          {
            user_id_arg: user_id,
            search_term: search,
            page_num: page,
            page_size: limit,
            filter_id_arg: filterId,
            sort_column: sortColumn,
            sort_direction: sortDirection,
          }
        );

        if (error) throw error;
        data = rpcData;

        const { data: countData, error: countError } = await supabase.rpc(
          "search_clients_by_user_count",
          {
            user_id_arg: user_id,
            search_term: search,
            filter_id_arg: filterId,
          }
        );
        if (countError) throw countError;
        count = countData;
      } else {
        // Original logic for non-search requests
        let query = supabase
          .from("clients")
          .select("*", { count: "exact" })
          .eq("user_id", user_id)
          .order(sortColumn, { ascending: sortDirection === "asc" });

        if (filterId) {
          query = query.eq("id", filterId);
        }

        if (limit !== -1) {
          const startIndex = (page - 1) * limit;
          query = query.range(startIndex, startIndex + limit - 1);
        }

        const { data: queryData, count: queryCount, error } = await query;
        if (error) throw error;
        data = queryData;
        count = queryCount;
      }

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
        ...clientData,
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
          ...clientData,
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
