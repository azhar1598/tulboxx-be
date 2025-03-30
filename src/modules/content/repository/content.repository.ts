// import { supabase } from "../../../config/database";
import { ContentModel } from "../model/content.model";
import {
  CreateContentRequest,
  // UpdateContentRequest,
} from "../dto/create-content.dto";
import { supabase } from "@/supabaseClient";
import { PaginationOptions, PaginatedResponse } from "@/types/pagination";

export class ContentRepository {
  private readonly tableName = "contents";

  async create(
    data: CreateContentRequest,
    content?: string
  ): Promise<ContentModel> {
    const newContent = {
      project_id: data.projectId,
      post_type: data.postType,
      advice: data.advice,
      benefit: data.benefit,
      platform: data.platform,
      tone: data.tone,
      length: data.length,
      use_emojis: data.useEmojis,
      use_hashtags: data.useHashtags,
      content: content,
      status: "draft",
      created_at: new Date().toISOString(),
    };

    const { data: result, error } = await supabase
      .from(this.tableName)
      .insert(newContent)
      .select()
      .single();

    if (error) throw error;
    return result as ContentModel;
  }

  async findById(id: number): Promise<ContentModel | null> {
    const { data, error } = await supabase
      .from(this.tableName)
      .select("*")
      .eq("id", id)
      .single();

    if (error) throw error;
    return data as ContentModel;
  }

  async findByProjectId(
    projectId: string,
    options: PaginationOptions
  ): Promise<PaginatedResponse<ContentModel>> {
    const { page, limit } = options;
    const offset = (page - 1) * limit;

    const { data, error, count } = await supabase
      .from(this.tableName)
      .select("*", { count: "exact" })
      .eq("project_id", projectId)
      .range(offset, offset + limit - 1);

    if (error) throw error;

    return {
      data: data as ContentModel[],
      total: count || 0,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit),
    };
  }

  // async update(id: number, data: UpdateContentRequest): Promise<ContentModel> {
  //   const updateData = {
  //     ...data,
  //     updated_at: new Date().toISOString(),
  //   };

  //   // Convert camelCase to snake_case for database
  //   const dbUpdateData: Record<string, any> = {};
  //   for (const [key, value] of Object.entries(updateData)) {
  //     const snakeKey = key.replace(
  //       /[A-Z]/g,
  //       (letter) => `_${letter.toLowerCase()}`
  //     );
  //     dbUpdateData[snakeKey] = value;
  //   }

  //   const { data: result, error } = await supabase
  //     .from(this.tableName)
  //     .update(dbUpdateData)
  //     .eq("id", id)
  //     .select()
  //     .single();

  //   if (error) throw error;
  //   return result as ContentModel;
  // }

  async delete(id: number): Promise<void> {
    const { error } = await supabase.from(this.tableName).delete().eq("id", id);

    if (error) throw error;
  }
}
