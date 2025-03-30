import { Request, Response } from "express";
import { createClient } from "@supabase/supabase-js";

// Regular Supabase client for auth operations
const supabase = createClient(
  process.env.SUPABASE_URL || "",
  process.env.SUPABASE_ANON_KEY || ""
);

export class AuthController {
  async login(req: Request, res: Response) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        return res
          .status(400)
          .json({ error: "Email and password are required" });
      }

      // Authenticate with Supabase
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        if (error.message.includes("Invalid login credentials")) {
          return res.status(401).json({ error: "Incorrect email or password" });
        }
        return res.status(500).json({ error: error.message });
      }

      // Handle cases where no user is found (edge case)
      if (!data.user) {
        return res.status(404).json({ error: "User not found" });
      }

      // Return session and user data
      return res.status(200).json({
        user: {
          id: data.user.id,
          email: data.user.email,
          user_metadata: data.user.user_metadata || {},
        },
        session: {
          access_token: data.session?.access_token,
          refresh_token: data.session?.refresh_token,
          expires_at: data.session?.expires_at,
        },
      });
    } catch (error: any) {
      console.error("Login error:", error.message);
      return res.status(500).json({ error: "Login failed. Please try again." });
    }
  }

  // Register with Email/Password
  async signup(req: Request, res: Response) {
    try {
      const { firstName, lastName, email, password } = req.body;

      if (!email || !password) {
        return res
          .status(400)
          .json({ error: "Email and password are required" });
      }

      const { data, error } = await supabase.auth.signUp({
        email,
        password,
      });

      if (error) {
        return res.status(400).json({ error: error.message });
      }

      // Insert user data into the profiles table
      const userId = data.user?.id;
      if (userId) {
        const { error: profileError } = await supabase.from("users").insert([
          {
            id: userId,
            first_name: firstName,
            last_name: lastName,
            email: email,
          },
        ]);

        if (profileError) {
          console.error("user insert error:", profileError.message);
        }
      }

      return res.status(201).json({ user: data.user });
    } catch (error: any) {
      console.error("Signup error:", error.message);
      return res
        .status(500)
        .json({ error: "Registration failed. Please try again." });
    }
  }
}
