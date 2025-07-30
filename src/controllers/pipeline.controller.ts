import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";

// Zod schema for stage validation
const stageSchema = z.object({
  name: z.string().min(1, "Name is required"),
  description: z.string().optional(),
  color: z.string().min(1, "Color is required"),
});

// Zod schema for lead validation
const leadSchema = z.object({
  customerId: z.string().uuid("Invalid customer ID"),
  stageId: z.string().uuid("Invalid stage ID"),
  estimatedValue: z
    .number()
    .positive("Estimated value must be a positive number"),
  expectedCloseDate: z.coerce.date(),
  notes: z.string().optional(),
});

export class PipelineController {
  // STAGE CONTROLLERS
  async getStages(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { data, error } = await supabase
        .from("pipeline_stages")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", { ascending: true });

      if (error) throw error;

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching stages:", error);
      return res.status(500).json({ error: "Failed to fetch stages" });
    }
  }

  async createStage(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const validationResult = stageSchema.safeParse(req.body);
      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const dataToInsert = {
        ...validationResult.data,
        user_id,
      };

      const { data, error } = await supabase
        .from("pipeline_stages")
        .insert(dataToInsert)
        .select()
        .single();

      if (error) throw error;

      return res
        .status(201)
        .json({ message: "Stage created successfully", stage: data });
    } catch (error) {
      console.error("Error creating stage:", error);
      return res.status(500).json({ error: "Failed to create stage" });
    }
  }

  async updateStage(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const validationResult = stageSchema.safeParse(req.body);
      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const { data, error } = await supabase
        .from("pipeline_stages")
        .update(validationResult.data)
        .eq("id", id)
        .eq("user_id", user_id)
        .select()
        .single();

      if (error) throw error;
      if (!data) return res.status(404).json({ error: "Stage not found" });

      return res
        .status(200)
        .json({ message: "Stage updated successfully", stage: data });
    } catch (error) {
      console.error("Error updating stage:", error);
      return res.status(500).json({ error: "Failed to update stage" });
    }
  }

  async deleteStage(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { error } = await supabase
        .from("pipeline_stages")
        .delete()
        .eq("id", id)
        .eq("user_id", user_id);

      if (error) throw error;

      return res.status(200).json({ message: "Stage deleted successfully" });
    } catch (error) {
      console.error("Error deleting stage:", error);
      return res.status(500).json({ error: "Failed to delete stage" });
    }
  }

  // LEAD CONTROLLERS

  async getLeads(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { data, error } = await supabase
        .from("pipeline_leads")
        .select("*, client:clients(name, email, phone)")
        .eq("user_id", user_id);

      if (error) throw error;

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching leads:", error);
      return res.status(500).json({ error: "Failed to fetch leads" });
    }
  }

  async getLeadById(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;

      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { data, error } = await supabase
        .from("pipeline_leads")
        .select("*, client:clients(name, email, phone)")
        .eq("id", id)
        .eq("user_id", user_id)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "Lead not found" });
        }
        throw error;
      }

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching lead:", error);
      return res.status(500).json({ error: "Failed to fetch lead" });
    }
  }

  async createLead(req: Request, res: Response) {
    try {
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const validationResult = leadSchema.safeParse(req.body);
      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const { customerId, stageId, estimatedValue, expectedCloseDate, notes } =
        validationResult.data;

      const dataToInsert = {
        client_id: customerId,
        stage_id: stageId,
        estimated_value: estimatedValue,
        expected_close_date: expectedCloseDate,
        notes: notes,
        user_id,
      };

      const { data, error } = await supabase
        .from("pipeline_leads")
        .insert(dataToInsert)
        .select()
        .single();

      if (error) throw error;

      return res
        .status(201)
        .json({ message: "Lead created successfully", lead: data });
    } catch (error) {
      console.error("Error creating lead:", error);
      return res.status(500).json({ error: "Failed to create lead" });
    }
  }

  async updateLead(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const validationResult = leadSchema.partial().safeParse(req.body);
      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const { customerId, stageId, estimatedValue, expectedCloseDate, notes } =
        validationResult.data;

      const dataToUpdate: any = {};
      if (customerId) dataToUpdate.client_id = customerId;
      if (stageId) dataToUpdate.stage_id = stageId;
      if (estimatedValue) dataToUpdate.estimated_value = estimatedValue;
      if (expectedCloseDate)
        dataToUpdate.expected_close_date = expectedCloseDate;
      if (notes) dataToUpdate.notes = notes;

      const { data, error } = await supabase
        .from("pipeline_leads")
        .update(dataToUpdate)
        .eq("id", id)
        .eq("user_id", user_id)
        .select()
        .single();

      if (error) throw error;
      if (!data) return res.status(404).json({ error: "Lead not found" });

      return res
        .status(200)
        .json({ message: "Lead updated successfully", lead: data });
    } catch (error) {
      console.error("Error updating lead:", error);
      return res.status(500).json({ error: "Failed to update lead" });
    }
  }

  async deleteLead(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const { error } = await supabase
        .from("pipeline_leads")
        .delete()
        .eq("id", id)
        .eq("user_id", user_id);

      if (error) throw error;

      return res.status(200).json({ message: "Lead deleted successfully" });
    } catch (error) {
      console.error("Error deleting lead:", error);
      return res.status(500).json({ error: "Failed to delete lead" });
    }
  }
}
