import { supabase } from "../../supabaseClient";
import { z } from "zod";

export class JobPublicController {
  async createJob(req: any, res: any) {
    try {
      const { role, description, payment_type, startup_id } = req.body;

      const userId = req.user?.id;

      console.log("userId: " + userId);

      if (!userId) {
        return res.status(401).json({
          error: "Unauthorized: User ID is required",
        });
      }

      // Validate required fields
      if (!role || !description || !payment_type || !startup_id) {
        return res.status(400).json({
          error:
            "Missing required fields: role, description, payment_type, and startup_title are required",
        });
      }

      // Validate payment_type enum values
      const validPaymentTypes = ["PAID", "UNPAID", "EQUITY_SPLIT"];
      if (!validPaymentTypes.includes(payment_type)) {
        return res.status(400).json({
          error:
            "Invalid payment_type. Must be one of: PAID, UNPAID, EQUITY_SPLIT",
        });
      }

      // Fetch the user's startup details based on title
      const { data: startup, error: startupError } = await supabase
        .from("startups")
        .select(
          `
         id,
          title,
          type,
          stage,
          description,
          category,
          team_size,
          website_url
        `
        )
        .eq("id", startup_id)
        .eq("user_id", userId)
        .single();

      if (startupError || !startup) {
        console.error("Error fetching startup details:", startupError);
        return res.status(404).json({
          error:
            "Startup not found or you don't have permission to create jobs for this startup",
        });
      }

      // Create the job posting with startup details
      const { data: jobData, error: jobError } = await supabase
        .from("jobs")
        .insert([
          {
            role,
            description,
            payment_type,
            startup_id: startup.id,
            created_at: new Date(),
          },
        ]).select(`
          *,
          startup:startups (
            id,
            title,
            type,
            stage,
            description,
            category,
            team_size,
            website_url,
            created_at
          )
        `);

      if (jobError) {
        console.error("Error creating job:", jobError);
        return res.status(500).json({
          error: "Failed to create job posting",
          details: jobError.message,
        });
      }

      return res.status(201).json({
        message: "Job posting created successfully",
        job: jobData[0],
      });
    } catch (error: any) {
      console.error("Server error:", error);
      return res.status(500).json({
        error: "Internal server error",
        details: error.message,
      });
    }
  }

  async getPublicJobs(req: any, res: any) {
    try {
      const { startup_id } = req.params; // Get startup_id from URL params

      if (!startup_id) {
        return res.status(400).json({
          error: "startup_id is required",
        });
      }

      // Execute the query to get jobs for the startup
      const { data: jobs, error } = await supabase
        .from("jobs")
        .select("*") // Select all columns from jobs
        .eq("startup_id", startup_id); // Filter by startup_id

      console.log("data----->", jobs);

      if (error) {
        console.error("Error fetching startup jobs:", error);
        return res.status(500).json({
          error: "Failed to fetch startup jobs",
          details: error.message,
        });
      }

      return res.status(200).json({
        jobs,
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
