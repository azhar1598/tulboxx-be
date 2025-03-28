import { Request, Response, NextFunction } from "express";
import { supabase } from "../supabaseClient";

export async function authMiddleware(req: any, res: any, next: NextFunction) {
  try {
    const token = req.headers.authorization?.replace("Bearer ", "");

    if (!token) {
      return res.status(401).json({ error: "No token provided" });
    }

    const {
      data: { user },
      error,
    } = await supabase.auth.getUser(token);

    if (error || !user) {
      return res.status(401).json({ error: "Invalid token" });
    }

    // Set the user object on the request
    req.user = {
      id: user.id,
      email: user.email,
      // Add other user properties as needed
    };

    next();
  } catch (error) {
    console.error("Auth error:", error);
    res.status(401).json({ error: "Authentication failed" });
  }
}
