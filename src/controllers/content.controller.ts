import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";
import { generateContentWithGemini } from "../utils/aiService";

// Define the schema for validation
const contentSchema = z.object({
  projectId: z.string().optional().nullable(),
  postType: z.string().min(1, "Post type is required"),
  advice: z.string().optional(),
  benefit: z.string().optional(),
  platform: z.string().min(1, "Platform is required"),
  tone: z.string().min(1, "Tone is required"),
  length: z.string().min(1, "Length is required"),
  useEmojis: z.boolean().default(false),
  useHashtags: z.boolean().default(false),
  user_id: z.string(),
});

export class ContentController {
  async getContents(req: Request, res: Response) {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 10;
      const startIndex = (page - 1) * limit;

      //   const { search } = req.query;
      console.log("query", req.query);

      const filterId = req.query["filter.id"] as string | undefined;
      const search = req.query["search"] as string | undefined;

      console.log("req.user.id", req.user, req);

      // Get authenticated user ID (modify this based on your auth setup)
      const user_id = req.user?.id; // Ensure this is available from your auth middleware

      console.log("user_id", user_id);
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Build the query with filtering
      let query = supabase
        .from("contents")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user_id)
        .order("created_at", { ascending: false }); // Add this line to sort by newest first

      if (filterId) {
        query = query.eq("id", filterId);
      }

      // Get total count of records
      const { count, error: countError } = await query;
      if (countError) throw countError;

      // Fetch paginated data with filter
      let dataQuery = supabase
        .from("contents")
        .select("*")
        .eq("user_id", user_id) // Ensure only the user’s estimates are fetched
        .range(startIndex, startIndex + limit - 1)
        .order("created_at", { ascending: false }); // Add this line to sort by newest first

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

      const response = {
        data: data.map((content) => ({
          ...content,
          project_name: content.estimates?.name || null, // Extract project name from the joined table
        })),
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
      console.error("Error fetching contents:", error);
      return res.status(500).json({ error: "Failed to fetch contents" });
    }
  }

  async createContent(req: Request, res: Response) {
    try {
      const validationResult = contentSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const contentData = validationResult.data;

      let generatedContent;
      try {
        generatedContent = await generateContentWithGemini(contentData);
      } catch (apiError: any) {
        console.error("Gemini API error:", apiError);
        return res.status(500).json({
          error: "Failed to generate content with AI",
          details: apiError.message,
        });
      }

      // Add metadata and generated content
      //   const dataToInsert = {
      //     ...contentData,
      //     content: generatedContent,
      //     created_at: new Date().toISOString(),
      //     status: "draft",
      //   };

      const dataToInsert = {
        project_id: contentData.projectId,
        post_type: contentData.postType,
        advice: contentData.advice,
        benefit: contentData.benefit,
        platform: contentData.platform,
        tone: contentData.tone,
        length: contentData.length,
        use_emojis: contentData.useEmojis,
        use_hashtags: contentData.useHashtags,
        content: generatedContent,
        created_at: new Date().toISOString(),
        user_id: contentData.user_id,
      };

      const { data, error } = await supabase
        .from("contents")
        .insert(dataToInsert)
        .select();

      if (error) throw error;

      return res.status(201).json({
        message: "Content created successfully",
        content: data[0],
      });
    } catch (error: any) {
      console.error("Error creating content:", error);
      return res.status(500).json({
        error: "Failed to create content",
        details: error.message,
      });
    }
  }

  async getContentById(req: Request, res: Response) {
    try {
      const { id } = req.params;

      //   const { data, error } = await supabase
      //     .from("contents")
      //     .select("*")
      //     .eq("id", id)
      //     .single();

      const { data, error } = await supabase
        .from("contents")
        .select(
          "*, estimates(projectName)" // Fetch all fields from `contents` + project name from `estimates`
        )
        .eq("id", id)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "Content not found" });
        }
        throw error;
      }

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching content:", error);
      return res.status(500).json({ error: "Failed to fetch content" });
    }
  }

  async updateContent(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const validationResult = contentSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const contentData = validationResult.data;

      // Update in database
      const { data, error } = await supabase
        .from("contents")
        .update({
          ...contentData,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id)
        .select();

      if (error) throw error;

      if (!data || data.length === 0) {
        return res.status(404).json({ error: "Content not found" });
      }

      return res.status(200).json({
        message: "Content updated successfully",
        content: data[0],
      });
    } catch (error: any) {
      console.error("Error updating content:", error);
      return res.status(500).json({
        error: "Failed to update content",
        details: error.message,
      });
    }
  }

  async deleteContent(req: Request, res: Response) {
    try {
      const { id } = req.params;

      const { error } = await supabase.from("contents").delete().eq("id", id);

      if (error) throw error;

      return res.status(200).json({
        message: "Content deleted successfully",
      });
    } catch (error: any) {
      console.error("Error deleting content:", error);
      return res.status(500).json({
        error: "Failed to delete content",
        details: error.message,
      });
    }
  }

  async getContentsByProjectId(req: Request, res: Response) {
    try {
      const { projectId } = req.params;

      // Extract pagination parameters from query
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 10;
      const startIndex = (page - 1) * limit;

      // First, get the total count of records for this project
      const { count, error: countError } = await supabase
        .from("contents")
        .select("*", { count: "exact", head: true })
        .eq("projectId", projectId);

      if (countError) throw countError;

      // Then fetch the paginated data
      const { data, error } = await supabase
        .from("contents")
        .select("*")
        .eq("projectId", projectId)
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
      console.error("Error fetching contents by project ID:", error);
      return res.status(500).json({ error: "Failed to fetch contents" });
    }
  }
}
