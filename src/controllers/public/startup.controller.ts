import { supabase } from "../../supabaseClient";
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

export class StartupPublicController {
  async getPublicStartups(req: any, res: any) {
    try {
      // Validate and parse query parameters
      const validation = QuerySchema.safeParse(req.query);
      if (!validation.success) {
        return res.status(400).json({
          error: "Invalid query parameters",
          details: validation.error.issues,
        });
      }

      console.log("get startups----->");

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
      let query = supabase.from("startups").select(
        `
                *,
                startup_roles (*)
              `,
        { count: "exact" }
      );

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
