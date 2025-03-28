import { supabase } from "../supabaseClient";
import { z } from "zod";

// Zod schema for validation
const RoleSchema = z.object({
  title: z.string().min(1, "Title is required"),
  details: z.string().min(1, "Details are required"),
  paymentType: z.enum(["PAID", "UNPAID", "EQUITY_SPLIT"]),
});

const CreateJobsSchema = z.object({
  roles: z.array(RoleSchema),
  startup_id: z.string().uuid("Invalid startup ID"),
});

export class JobController {
  async createJob(req: any, res: any) {
    try {
      const { roles, startup_id } = req.body;
      const userId = req.user?.id;

      console.log("userId", req?.user);

      if (!userId) {
        return res.status(401).json({
          error: "Unauthorized: User ID is required",
        });
      }

      // Validate request body using Zod
      try {
        CreateJobsSchema.parse(req.body);
      } catch (validationError: any) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationError.errors,
        });
      }

      // Check if startup exists and belongs to user
      const { data: startup, error: startupError } = await supabase
        .from("startups")
        .select("id")
        .eq("id", startup_id)
        .eq("user_id", userId)
        .single();

      if (startupError || !startup) {
        return res.status(404).json({
          error:
            "Startup not found or you don't have permission to create jobs for this startup",
        });
      }

      // Prepare jobs data for insertion
      const jobsToInsert = roles.map((role: any) => ({
        title: role.title,
        details: role.details,
        payment_type: role.paymentType,
        startup_id,
        created_at: new Date(),
      }));

      // Insert all jobs
      const { data: jobsData, error: jobsError } = await supabase
        .from("jobs")
        .insert(jobsToInsert)
        .select();

      if (jobsError) {
        console.error("Error creating jobs:", jobsError);
        return res.status(500).json({
          error: "Failed to create job postings",
          details: jobsError.message,
        });
      }

      return res.status(201).json({
        message: "Job postings created successfully",
        jobs: jobsData,
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
