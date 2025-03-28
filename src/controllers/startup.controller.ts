import { supabase } from "../supabaseClient";
import { z } from "zod";

const QuerySchema = z.object({
  page: z.string().optional().default("1"),
  limit: z.string().optional().default("10"),
  search: z.string().optional(),
  category: z.string().optional(),
  stage: z.string().optional(),
  type: z.string().optional(),
  teamSize: z.string().optional(),
  orderBy: z.string().optional().default("created_at"),
  order: z.enum(["asc", "desc"]).optional().default("desc"),
});

const SearchableFields = [
  "title",
  "description",
  "category",
  "stage",
  "type",
  "team_size",
] as const;
type SearchField = (typeof SearchableFields)[number];

// Utility function to sanitize search input
function sanitizeSearchTerm(term: string): string {
  return term
    .replace(/[%_]/g, "") // Remove SQL wildcard characters
    .trim()
    .toLowerCase();
}

export class StartupController {
  async createStartup(req: any, res: any) {
    try {
      const { title, stage, description, category, teamSize, website } =
        req.body;

      const userId = req.user?.id;

      console.log("userId" + userId);

      if (!userId) {
        return res.status(401).json({
          error: "Unauthorized: User ID is required",
        });
      }

      // Validate required fields
      if (!title || !description || !category) {
        return res.status(400).json({
          error:
            "Missing required fields: title, description, and category are required",
        });
      }

      // Check for existing startup with same name by this user
      const { data: existingStartup, error: checkError } = await supabase
        .from("startups")
        .select("id")
        .eq("title", title)
        .eq("user_id", userId)
        .single();

      if (checkError && checkError.code !== "PGRST116") {
        // PGRST116 is the "not found" error code
        console.error("Error checking existing startup:", checkError);
        return res.status(500).json({
          error: "Failed to check existing startup",
          details: checkError.message,
        });
      }

      if (existingStartup) {
        return res.status(400).json({
          error: "You already have a startup project with this name",
        });
      }

      // First, insert the startup
      const { data: startupData, error: startupError } = await supabase
        .from("startups")
        .insert([
          {
            title,
            stage,
            description,
            category,
            team_size: teamSize,
            website_url: website,
            created_at: new Date(),
            user_id: userId, // Add the user_id to the startup record
          },
        ])
        .select();

      if (startupError) {
        console.error("Error creating startup:", startupError);
        return res.status(500).json({
          error: "Failed to create startup",
          details: startupError.message,
        });
      }

      const startupId = startupData[0].id;

      // Then, insert all roles for this startup
      //   if (roles && roles.length > 0) {
      //     const rolesWithStartupId = roles?.map((role: any) => ({
      //       startup_id: startupId,
      //       title: role.title,
      //       details: role.details,
      //       payment_type: role.paymentType,
      //       user_id: userId, // Add the user_id to each role record
      //     }));

      //     const { error: rolesError } = await supabase
      //       .from("startup_roles")
      //       .insert(rolesWithStartupId);

      //     if (rolesError) {
      //       console.error("Error creating roles:", rolesError);
      //       // You might want to delete the startup if roles creation fails
      //       await supabase.from("startups").delete().eq("id", startupId);
      //       return res.status(500).json({
      //         error: "Failed to create roles",
      //         details: rolesError.message,
      //       });
      //     }
      //   }

      return res.status(201).json({
        message: "Startup created successfully",
        startup: startupData[0],
      });
    } catch (error: any) {
      console.error("Server error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error.message,
      });
    }
  }

  async getStartups(req: any, res: any) {
    try {
      const userId = req.user?.id;

      // Check authentication
      if (!userId) {
        return res.status(401).json({
          error: "Unauthorized: User ID is required",
        });
      }

      // Validate and parse query parameters
      const validation = QuerySchema.safeParse(req.query);
      if (!validation.success) {
        return res.status(400).json({
          error: "Invalid query parameters",
          details: validation.error.issues,
        });
      }

      const {
        page,
        limit,
        search,
        category,
        stage,
        type,
        teamSize,
        orderBy,
        order,
      } = validation.data;

      // Calculate pagination offset
      const offset = (Number(page) - 1) * Number(limit);

      // Build base query
      let query = supabase
        .from("startups")
        .select(
          `
            *,
            startup_roles (*)
          `,
          { count: "exact" }
        )
        .eq("user_id", userId);

      // Add search filters
      if (search) {
        query = query.or(
          `title.ilike.%${search}%,description.ilike.%${search}%`
        );
      }

      // Add category filter
      if (category) {
        query = query.eq("category", category);
      }

      // Add stage filter
      if (stage) {
        query = query.eq("stage", stage);
      }

      // Add type filter
      if (type) {
        query = query.eq("type", type);
      }

      // Add team size filter
      if (teamSize) {
        query = query.eq("team_size", teamSize);
      }

      // Add ordering
      query = query
        .order(orderBy, { ascending: order === "asc" })
        .range(offset, offset + Number(limit) - 1);

      // Execute query
      const { data: startups, error, count } = await query;

      // Handle database errors
      if (error) {
        console.error("Database error:", error);
        return res.status(500).json({
          error: "Failed to fetch startups",
          details: error.message,
        });
      }

      // Handle empty results
      if (!startups || startups.length === 0) {
        return res.status(200).json({
          data: [],
          metadata: {
            total: 0,
            page: Number(page),
            limit: Number(limit),
            totalPages: 0,
            hasNextPage: false,
            hasPreviousPage: false,
          },
        });
      }

      // Calculate pagination metadata
      const totalPages = count ? Math.ceil(count / Number(limit)) : 0;
      const hasNextPage = Number(page) < totalPages;
      const hasPreviousPage = Number(page) > 1;

      // Return successful response
      return res.status(200).json({
        data: startups,
        metadata: {
          total: count,
          page: Number(page),
          limit: Number(limit),
          totalPages,
          hasNextPage,
          hasPreviousPage,
        },
      });
    } catch (error: any) {
      console.error("Server error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error.message,
      });
    }
  }

  async updateStartup(req: any, res: any) {
    try {
      const startupId = req.params.id;
      const userId = req.user?.id;
      const {
        title,
        type,
        stage,
        description,
        category,
        teamSize,
        website,
        skills,
        roles,
      } = req.body;

      // Check if user is authenticated
      if (!userId) {
        return res.status(401).json({
          error: "Unauthorized: User ID is required",
        });
      }

      // First check if the startup exists and belongs to the user
      const { data: existingStartup, error: fetchError } = await supabase
        .from("startups")
        .select("*")
        .eq("id", startupId)
        .eq("user_id", userId)
        .single();

      if (fetchError || !existingStartup) {
        return res.status(404).json({
          error: "Startup not found or you don't have permission to update it",
        });
      }

      // If title is being changed, check for duplicates
      if (title && title !== existingStartup.title) {
        const { data: duplicateCheck, error: duplicateError } = await supabase
          .from("startups")
          .select("id")
          .eq("title", title)
          .eq("user_id", userId)
          .neq("id", startupId)
          .single();

        if (duplicateCheck) {
          return res.status(400).json({
            error: "You already have another startup with this name",
          });
        }
      }

      // Prepare update object with only provided fields
      const updateData: any = {};
      if (title) updateData.title = title;
      if (type) updateData.type = type;
      if (stage) updateData.stage = stage;
      if (description) updateData.description = description;
      if (category) updateData.category = category;
      if (teamSize) updateData.team_size = teamSize;
      if (website) updateData.website_url = website;
      if (skills) updateData.skills = skills;
      updateData.updated_at = new Date();

      // Update the startup
      const { data: updatedStartup, error: updateError } = await supabase
        .from("startups")
        .update(updateData)
        .eq("id", startupId)
        .eq("user_id", userId)
        .select()
        .single();

      if (updateError) {
        console.error("Error updating startup:", updateError);
        return res.status(500).json({
          error: "Failed to update startup",
          details: updateError.message,
        });
      }

      // Update roles if provided
      if (roles && roles.length > 0) {
        // First, delete existing roles
        const { error: deleteRolesError } = await supabase
          .from("startup_roles")
          .delete()
          .eq("startup_id", startupId);

        if (deleteRolesError) {
          console.error("Error deleting existing roles:", deleteRolesError);
          return res.status(500).json({
            error: "Failed to update roles",
            details: deleteRolesError.message,
          });
        }

        // Then insert new roles
        const rolesWithIds = roles.map((role: any) => ({
          startup_id: startupId,
          title: role.title,
          details: role.details,
          payment_type: role.paymentType,
          user_id: userId,
        }));

        const { error: insertRolesError } = await supabase
          .from("startup_roles")
          .insert(rolesWithIds);

        if (insertRolesError) {
          console.error("Error creating new roles:", insertRolesError);
          return res.status(500).json({
            error: "Failed to update roles",
            details: insertRolesError.message,
          });
        }
      }

      // Fetch the final startup with its roles
      const { data: finalStartup, error: finalError } = await supabase
        .from("startups")
        .select(
          `
          *,
          startup_roles (*)
        `
        )
        .eq("id", startupId)
        .single();

      return res.status(200).json({
        message: "Startup updated successfully",
        startup: finalStartup,
      });
    } catch (error: any) {
      console.error("Server error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error.message,
      });
    }
  }

  async deleteStartup(req: any, res: any) {
    try {
      const startupId = req.params.id;
      const userId = req.user?.id;

      // Check if user is authenticated
      if (!userId) {
        return res.status(401).json({
          error: "Unauthorized: User ID is required",
        });
      }

      // First check if the startup exists and belongs to the user
      const { data: existingStartup, error: fetchError } = await supabase
        .from("startups")
        .select("id")
        .eq("id", startupId)
        .eq("user_id", userId)
        .single();

      if (fetchError || !existingStartup) {
        return res.status(404).json({
          error: "Startup not found or you don't have permission to delete it",
        });
      }

      // First delete all associated roles
      const { error: rolesDeleteError } = await supabase
        .from("startup_roles")
        .delete()
        .eq("startup_id", startupId);

      if (rolesDeleteError) {
        console.error("Error deleting startup roles:", rolesDeleteError);
        return res.status(500).json({
          error: "Failed to delete startup roles",
          details: rolesDeleteError.message,
        });
      }

      // Then delete the startup
      const { error: startupDeleteError } = await supabase
        .from("startups")
        .delete()
        .eq("id", startupId)
        .eq("user_id", userId);

      if (startupDeleteError) {
        console.error("Error deleting startup:", startupDeleteError);
        return res.status(500).json({
          error: "Failed to delete startup",
          details: startupDeleteError.message,
        });
      }

      return res.status(200).json({
        message: "Startup and associated roles deleted successfully",
        deletedId: startupId,
      });
    } catch (error: any) {
      console.error("Server error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error.message,
      });
    }
  }

  async getStartupSingle(req: any, res: any) {
    try {
      const startupId = req.params.id;
      const userId = req.user?.id;

      // Check if user is authenticated
      if (!userId) {
        return res.status(401).json({
          error: "Unauthorized: User ID is required",
        });
      }

      // Fetch the startup with its roles
      const { data: startup, error: fetchError } = await supabase
        .from("startups")
        .select(
          `
          *,
          startup_roles (*)
        `
        )
        .eq("id", startupId)
        .eq("user_id", userId) // Ensure user can only see their own startup
        .single();

      if (fetchError) {
        console.error("Error fetching startup:", fetchError);
        return res.status(404).json({
          error: "Startup not found or you don't have permission to view it",
        });
      }

      if (!startup) {
        return res.status(404).json({
          error: "Startup not found",
        });
      }

      return res.status(200).json({
        data: startup,
      });
    } catch (error: any) {
      console.error("Server error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error.message,
      });
    }
  }

  async searchStartups(req: any, res: any) {
    try {
      const {
        search = "", // for startup name
        category,
        teamSize,
        page = 1,
        limit = 10,
        orderBy = "created_at",
        order = "desc",
      } = req.query;

      // Calculate offset for pagination
      const offset = (Number(page) - 1) * Number(limit);

      // Start building the query
      let query = supabase.from("startups").select(
        `
          *,
          startup_roles (*)
        `,
        { count: "exact" }
      );

      // Add search filters
      if (search) {
        query = query.ilike("title", `%${search}%`);
      }

      if (category) {
        // Handle multiple categories if provided as comma-separated
        const categories = category.split(",").map((c: string) => c.trim());
        query = query.in("category", categories);
      }

      if (teamSize) {
        // Handle team size ranges
        // Example: "1-10" or "10-50" or "50+"
        switch (teamSize) {
          case "1-10":
            query = query.lte("team_size", 10);
            break;
          case "10-50":
            query = query.gt("team_size", 10).lte("team_size", 50);
            break;
          case "50+":
            query = query.gt("team_size", 50);
            break;
          default:
            // If exact number provided
            query = query.eq("team_size", Number(teamSize));
        }
      }

      // Add pagination and ordering
      query = query
        .order(orderBy, { ascending: order === "asc" })
        .range(offset, offset + Number(limit) - 1);

      // Execute the query
      const { data: startups, error, count } = await query;

      if (error) {
        console.error("Error searching startups:", error);
        return res.status(500).json({
          error: "Failed to search startups",
          details: error.message,
        });
      }

      // Calculate pagination metadata
      const totalPages = count ? Math.ceil(count / Number(limit)) : 0;
      const hasNextPage = page < totalPages;
      const hasPreviousPage = page > 1;

      // Get unique categories for filters
      const { data: categories, error: categoryError } = await supabase
        .from("startups")
        .select("category")
        .not("category", "is", null);

      const uniqueCategories = categories
        ? [...new Set(categories.map((item) => item.category))].filter(Boolean)
        : [];

      return res.status(200).json({
        data: startups,
        metadata: {
          total: count,
          page: Number(page),
          limit: Number(limit),
          totalPages,
          hasNextPage,
          hasPreviousPage,
        },
        filters: {
          availableCategories: uniqueCategories,
          teamSizeRanges: ["1-10", "10-50", "50+"],
        },
      });
    } catch (error: any) {
      console.error("Server error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error.message,
      });
    }
  }
}
