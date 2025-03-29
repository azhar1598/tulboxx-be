// import { Request, Response } from "express";
// import { supabase } from "../supabaseClient";

// export class AuthController {
//   async login(req: Request, res: Response) {
//     const { data, error } = await supabase.auth.signInWithOAuth({
//       provider: "google",
//       options: {
//         redirectTo: "http://localhost:3000/auth/callback", // Adjust to match your app's callback route
//       },
//     });

//     if (error) {
//       console.error("OAuth Error:", error.message);
//       return res.status(500).json({ message: "Failed to initiate login" });
//     }

//     // Redirect the user to the OAuth login URL
//     res.redirect(data.url);
//   }

//   //   async callback(req: Request, res: Response) {
//   //     const { code } = req.query;

//   //     if (!code) return res.status(400).send("Authorization code missing");

//   //     try {
//   //       const { data, error } = await supabase.auth.exchangeCodeForSession(
//   //         code as string
//   //       );

//   //       if (error) throw error;

//   //       const session = data.session;

//   //       // Redirect to your frontend with the session
//   //       res.redirect("http://localhost:3000/dashboard"); // Or wherever you want to redirect after successful login
//   //     } catch (error) {
//   //       console.error("Callback Error:", error);
//   //       res.status(500).json({ message: "Failed to handle callback" });
//   //     }
//   //   }

//   async callback(req: Request, res: Response) {
//     const { code } = req.query;

//     if (!code) {
//       return res.status(400).json({ error: "No code provided" });
//     }

//     try {
//       const { data, error } = await supabase.auth.exchangeCodeForSession(
//         code as string
//       );

//       if (error) throw error;

//       // Set session cookie or handle as needed
//       res.cookie("auth-token", data.session.access_token, {
//         httpOnly: true,
//         secure: process.env.NODE_ENV === "production",
//         sameSite: "lax",
//         maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
//       });

//       // Redirect to your frontend
//       res.redirect("http://localhost:3000/dashboard");
//     } catch (error) {
//       console.error("Callback error:", error);
//       res.redirect("http://localhost:3000/auth/error");
//     }
//   }
// }

import { Request, Response } from "express";
import { createClient } from "@supabase/supabase-js";

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY, // Use service role key for admin operations
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);

export class AuthController {
  async login(req: Request, res: Response) {
    try {
      // Generate OAuth URL using Supabase Admin client
      const { data, error } = await supabaseAdmin.auth.admin.generateLink({
        // type: "oauth",
        provider: "google",
        options: {
          redirectTo: "http://localhost:3000/auth/callback",
        },
      });

      if (error) throw error;

      // Return the URL instead of redirecting
      res.json({ url: data.url });
    } catch (error: any) {
      console.error("OAuth Error:", error.message);
      res.status(500).json({ error: "Failed to initiate login" });
    }
  }

  async callback(req: Request, res: Response) {
    const { code } = req.query;

    if (!code) {
      return res.status(400).json({ error: "No code provided" });
    }

    try {
      // Exchange code for session
      const {
        data: { session },
        error,
      } = await supabaseAdmin.auth.admin.generateSession(code as string);

      if (error) throw error;

      // Store both access and refresh tokens
      res.cookie("sb-access-token", session.access_token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        maxAge: 60 * 60 * 1000, // 1 hour
      });

      res.cookie("sb-refresh-token", session.refresh_token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
      });

      // Store user data if needed
      const {
        data: { user },
        error: userError,
      } = await supabaseAdmin.auth.admin.getUserById(session.user.id);

      if (userError) throw userError;

      // Redirect to frontend with success
      res.redirect("http://localhost:3000/dashboard");
    } catch (error: any) {
      console.error("Callback error:", error.message);
      res.redirect("http://localhost:3000/auth/error");
    }
  }

  // Add refresh token endpoint
  async refresh(req: Request, res: Response) {
    const refreshToken = req.cookies["sb-refresh-token"];

    if (!refreshToken) {
      return res.status(401).json({ error: "No refresh token" });
    }

    try {
      const {
        data: { session },
        error,
      } = await supabaseAdmin.auth.admin.refreshSession(refreshToken);

      if (error) throw error;

      // Update cookies with new tokens
      res.cookie("sb-access-token", session.access_token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        maxAge: 60 * 60 * 1000,
      });

      res.cookie("sb-refresh-token", session.refresh_token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        maxAge: 7 * 24 * 60 * 60 * 1000,
      });

      res.json({ message: "Session refreshed" });
    } catch (error: any) {
      console.error("Refresh error:", error.message);
      res.status(401).json({ error: "Invalid refresh token" });
    }
  }

  // Add logout endpoint
  async logout(req: Request, res: Response) {
    const accessToken = req.cookies["sb-access-token"];

    if (accessToken) {
      try {
        await supabaseAdmin.auth.admin.signOut(accessToken);
      } catch (error) {
        console.error("Logout error:", error);
      }
    }

    res.clearCookie("sb-access-token");
    res.clearCookie("sb-refresh-token");
    res.json({ message: "Logged out successfully" });
  }
}
