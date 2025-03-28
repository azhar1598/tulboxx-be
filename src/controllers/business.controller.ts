import { Request, Response } from "express";
import { BusinessService } from "../services/business.service";
import { createClient } from "@supabase/supabase-js";
import { dummyGeminiData } from "../constants";

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        [key: string]: any;
      };
    }
  }
}

export class BusinessController {
  private businessService: BusinessService;
  private supabase;

  constructor() {
    this.businessService = new BusinessService();

    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Missing Supabase credentials in environment variables");
    }

    this.supabase = createClient(supabaseUrl, supabaseKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });
  }

  async getBusinessInsights(req: any, res: any) {
    try {
      const businessName = req.query.name as string;
      const userId = req.user?.id;

      if (!businessName) {
        return res.status(400).json({ error: "Business name is required" });
      }

      if (!userId) {
        return res
          .status(401)
          .json({ error: "Unauthorized: User ID is required" });
      }

      // First, check if we have existing insights for this business
      const { data: existingInsights, error: fetchError } = await this.supabase
        .from("business_insights")
        .select("*")
        .eq("business_name", businessName)
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();

      if (fetchError && fetchError.code !== "PGRST116") {
        // PGRST116 is the "not found" error code
        console.error("Error fetching existing insights:", fetchError);
        return res.status(500).json({
          error: "Failed to check existing insights",
          details: fetchError.message,
        });
      }

      // If we found existing insights, return them
      if (existingInsights) {
        return res.json({
          data: existingInsights.insights,
          savedRecord: existingInsights,
          source: "cache",
        });
      }

      // If no existing insights, fetch new ones
      const insights = await this.businessService.getBusinessInsights(
        businessName
      );
      console.log("insights", insights);

      if (!insights || typeof insights !== "object") {
        return res
          .status(500)
          .json({ error: "Failed to retrieve valid business insights" });
      }

      const businessData = {
        business_name: businessName,
        insights,
        user_id: userId,
        created_at: new Date().toISOString(),
      };

      // Save to Supabase
      const { data: savedData, error: supabaseError } = await this.supabase
        .from("business_insights")
        .insert([businessData])
        .select()
        .single();

      if (supabaseError) {
        console.error("Supabase Error:", supabaseError);
        return res.status(500).json({
          error: "Failed to save data to the database",
          details: supabaseError.message,
        });
      }

      return res.json({
        data: insights,
        savedRecord: savedData,
        source: "api",
      });
    } catch (error) {
      console.error("API Error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }

  async getHistoricalInsights(req: Request, res: Response) {
    try {
      const userId = req.user?.id;
      const businessName = req.query.name as string;

      let query = this.supabase
        .from("business_insights")
        .select("*")
        .order("created_at", { ascending: false });

      if (businessName) {
        query = query.eq("business_name", businessName);
      }

      if (userId) {
        query = query.eq("user_id", userId);
      }

      const { data, error } = await query;

      if (error) {
        throw error;
      }

      return res.json(data);
    } catch (error) {
      console.error("API Error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
}
