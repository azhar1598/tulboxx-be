// import { supabase } from "../../supabaseClient";
// import { z } from "zod";

export class EstimatePublicController {
  async getPublicEstimates(req: any, res: any) {
    return res.status(200).json({ "hello world": "hello world" });
  }
}
