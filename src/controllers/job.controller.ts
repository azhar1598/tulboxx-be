import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";

// Define the schema for job validation
const jobSchema = z.object({
  name: z.string().min(1, { message: "Job title is required" }),
  customer: z.preprocess((val) => {
    if (val === "" || val === null || val === undefined) return null;
    return val;
  }, z.string().uuid({ message: "Invalid customer ID" }).nullable().optional()),
  description: z.string().optional(),
  start_date: z.preprocess((val) => {
    if (val === "" || val === null || val === undefined) return null;
    const d = new Date(val as any);
    return isNaN(d.getTime()) ? null : d;
  }, z.date().nullable().optional()),
  end_date: z.preprocess((val) => {
    if (val === "" || val === null || val === undefined) return null;
    const d = new Date(val as any);
    return isNaN(d.getTime()) ? null : d;
  }, z.date().nullable().optional()),
  amount: z.preprocess((val) => {
    if (val === "" || val === null || val === undefined) return null;
    const num = Number(val);
    return isNaN(num) ? null : num;
  }, z.number().nonnegative({ message: "Amount must be non-negative" }).nullable().optional()),
  notes: z.string().optional(),
});

export class JobController {
  async getJobs(req: Request, res: Response) {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 10;
      const search = req.query["search"] as string | undefined;
      const sortBy = req.query.sortBy as string[] | string | undefined;

      let sortColumn = "created_at";
      let sortDirection = "desc";

      const allowedSortColumns = [
        "name",
        "start_date",
        "end_date",
        "amount",
        "created_at",
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

      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      let query = supabase
        .from("jobs")
        .select(
          `
          *,
          client:clients(name, email, phone)
        `,
          { count: "exact" }
        )
        .eq("user_id", user_id)
        .order(sortColumn, { ascending: sortDirection === "asc" });

      if (search) {
        query = query.or(
          `name.ilike.%${search}%,description.ilike.%${search}%`
        );
      }

      if (limit !== -1) {
        const startIndex = (page - 1) * limit;
        query = query.range(startIndex, startIndex + limit - 1);
      }

      const { data, count, error } = await query;

      if (error) throw error;

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
      console.error("Error fetching jobs:", error);
      return res.status(500).json({ error: "Failed to fetch jobs" });
    }
  }

  async createJob(req: Request, res: Response) {
    try {
      const validationResult = jobSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const { customer, ...jobData } = validationResult.data;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const dataToInsert = {
        ...jobData,
        client_id: customer,
        user_id: user_id,
      };

      const { data, error } = await supabase
        .from("jobs")
        .insert(dataToInsert)
        .select();

      if (error) throw error;

      return res.status(201).json({
        message: "Job created successfully",
        job: data[0],
      });
    } catch (error: any) {
      console.error("Error creating job:", error);
      return res.status(500).json({
        error: "Failed to create job",
        details: error.message,
      });
    }
  }

  async getJobById(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { data, error } = await supabase
        .from("jobs")
        .select(
          `
          *,
          client:clients(name, email, phone)
        `
        )
        .eq("id", id)
        .eq("user_id", user_id)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "Job not found" });
        }
        throw error;
      }

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching job:", error);
      return res.status(500).json({ error: "Failed to fetch job" });
    }
  }

  async updateJob(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { data: existingJob, error: fetchError } = await supabase
        .from("jobs")
        .select("id")
        .eq("id", id)
        .eq("user_id", user_id)
        .single();

      if (fetchError) {
        if (fetchError.code === "PGRST116") {
          return res.status(404).json({ error: "Job not found" });
        }
        throw fetchError;
      }

      const validationResult = jobSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const { customer, ...jobData } = validationResult.data;

      const { data, error } = await supabase
        .from("jobs")
        .update({
          ...jobData,
          client_id: customer,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id)
        .eq("user_id", user_id)
        .select();

      if (error) throw error;

      return res.status(200).json({
        message: "Job updated successfully",
        job: data[0],
      });
    } catch (error: any) {
      console.error("Error updating job:", error);
      return res.status(500).json({
        error: "Failed to update job",
        details: error.message,
      });
    }
  }

  async deleteJob(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { error: fetchError } = await supabase
        .from("jobs")
        .select("id")
        .eq("id", id)
        .eq("user_id", user_id)
        .single();

      if (fetchError) {
        if (fetchError.code === "PGRST116") {
          return res.status(404).json({ error: "Job not found" });
        }
        throw fetchError;
      }

      const { error } = await supabase
        .from("jobs")
        .delete()
        .eq("id", id)
        .eq("user_id", user_id);

      if (error) throw error;

      return res.status(200).json({
        message: "Job deleted successfully",
      });
    } catch (error: any) {
      console.error("Error deleting job:", error);
      return res.status(500).json({
        error: "Failed to delete job",
        details: error.message,
      });
    }
  }
}
