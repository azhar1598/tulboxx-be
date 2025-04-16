import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";
import { UserMetadata } from "firebase-admin/lib/auth/user-record";

// Define the schema for user profile validation matching the frontend schema
const userProfileSchema = z.object({
  fullName: z.string().min(1, "Full name is required"),
  email: z.string().email("Invalid email address").min(1, "Email is required"),
  phone: z.string().min(1, "Phone number is required"),
  address: z.string().min(1, "Address is required"),
  companyName: z.string().optional(),
  jobTitle: z.string().optional(),
  industry: z.string().optional(),
  companySize: z.string().optional(),
  currentPassword: z.string().optional(),
  newPassword: z.string().optional(),
  emailNotifications: z.boolean(),
  smsNotifications: z.boolean(),
});

export class UserController {
  async getUserProfile(req: Request, res: Response) {
    try {
      const userId = req.user?.id;

      if (!userId) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Query the view with proper RLS
      const { data, error } = await supabase
        .from("user_profiles")
        .select("*")
        .eq("id", userId)
        .single();

      if (error) {
        return res.status(500).json({ error: "Failed to fetch user profile" });
      }

      // Format and return the user data
      const formattedData = {
        id: data.id,
        email: data.email,
        emailConfirmed: data.email_confirmed,
        userMetadata: data.raw_user_meta_data,
        jobTitle: data.job_title,
        companyName: data.company_name,
        industry: data.industry,
        companySize: data.company_size,
        phone: data.phone,
        address: data.address,
      };

      return res.status(200).json(formattedData);
    } catch (error) {
      console.error("Error fetching user profile:", error);
      return res.status(500).json({ error: "Failed to fetch user profile" });
    }
  }

  async updateUserProfile(req: Request, res: Response) {
    try {
      const userId = req.user?.id;

      if (!userId) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Define validation schema for company details only
      const updateProfileSchema = z.object({
        companyName: z.string().optional(),
        companySize: z.string().optional(),
        address: z.string().optional(),
        plan: z.string().optional(),
        industry: z.string().optional(),
        jobTitle: z.string().optional(),
      });

      const validationResult = updateProfileSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const profileData = validationResult.data;

      // Format data to match database schema
      const formattedData: any = {
        company_name: profileData.companyName,
        company_size: profileData.companySize,
        address: profileData.address,
        plan: profileData.plan,
        industry: profileData.industry,
        job_title: profileData.jobTitle,
      };

      // Remove undefined values
      Object.keys(formattedData).forEach(
        (key) => formattedData[key] === undefined && delete formattedData[key]
      );

      // Update profile data
      const { data, error } = await supabase
        .from("profiles")
        .update(formattedData)
        .eq("id", userId)
        .select();

      if (error) {
        return res.status(500).json({
          error: "Failed to update profile",
          details: error.message,
        });
      }

      if (!data || data.length === 0) {
        return res.status(404).json({ error: "User not found" });
      }

      // Format response
      const responseData = {
        id: data[0].id,
        companyName: data[0].company_name,
        companySize: data[0].company_size,
        address: data[0].address,
        plan: data[0].plan,
        industry: data[0].industry,
        jobTitle: data[0].job_title,
      };

      return res.status(200).json({
        message: "Profile updated successfully",
        profile: responseData,
      });
    } catch (error: any) {
      console.error("Error updating user profile:", error);
      return res.status(500).json({
        error: "Failed to update profile",
        details: error.message,
      });
    }
  }

  async getAllUsers(req: Request, res: Response) {
    try {
      // Check if requesting user is an admin
      const userId = req.user?.id;
      const { data: adminCheck, error: adminError } = await supabase
        .from("users")
        .select("role")
        .or(`id.eq.${userId},id.eq.${userId}`)
        .single();

      if (adminError || adminCheck?.role !== "admin") {
        return res
          .status(403)
          .json({ error: "Forbidden: Admin access required" });
      }

      // Extract pagination parameters from query
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 10;
      const startIndex = (page - 1) * limit;

      // Get total count of users
      const { count, error: countError } = await supabase
        .from("users")
        .select("*", { count: "exact", head: true });

      if (countError) throw countError;

      // Fetch paginated users
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .range(startIndex, startIndex + limit - 1);

      if (error) throw error;

      const totalRecords = count || 0;
      const totalPages = Math.ceil(totalRecords / limit);

      // Format response to match frontend schema
      const formattedData = data.map((user) => ({
        id: user.id,
        userId: user.id || user.id,
        fullName: user.full_name,
        email: user.email,
        phone: user.phone,
        address: user.address,
        companyName: user.company_name,
        jobTitle: user.job_title,
        industry: user.industry,
        companySize: user.company_size,
        emailNotifications: user.email_notifications,
        smsNotifications: user.sms_notifications,
        role: user.role,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
      }));

      const response = {
        data: formattedData,
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
    } catch (error: any) {
      console.error("Error fetching users:", error);
      return res
        .status(500)
        .json({ error: "Failed to fetch users", details: error.message });
    }
  }

  async getUserById(req: Request, res: Response) {
    try {
      const { id } = req.params;

      // Check if requesting user is an admin or the requested user
      const requestingUserId = req.user?.id;
      if (id !== requestingUserId) {
        const { data: adminCheck, error: adminError } = await supabase
          .from("profiles")
          .select("role")
          .or(`id.eq.${requestingUserId},id.eq.${requestingUserId}`)
          .single();

        if (adminError || adminCheck?.role !== "admin") {
          return res
            .status(403)
            .json({ error: "Forbidden: Insufficient permissions" });
        }
      }

      // Try to find user by either id or id
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .or(`id.eq.${id},id.eq.${id}`)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "User not found" });
        }
        throw error;
      }

      // Format response to match frontend schema
      const formattedData = {
        id: data.id,
        userId: data.id || data.id,
        fullName: data.full_name,
        email: data.email,
        phone: data.phone,
        address: data.address,
        companyName: data.company_name,
        jobTitle: data.job_title,
        industry: data.industry,
        companySize: data.company_size,
        emailNotifications: data.email_notifications,
        smsNotifications: data.sms_notifications,
        role: data.role,
        createdAt: data.created_at,
        updatedAt: data.updated_at,
      };

      return res.status(200).json(formattedData);
    } catch (error: any) {
      console.error("Error fetching user:", error);
      return res
        .status(500)
        .json({ error: "Failed to fetch user", details: error.message });
    }
  }
}
