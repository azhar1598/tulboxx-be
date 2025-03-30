// src/dtos/content.dto.ts

import { z } from "zod";

// Frontend schema (camelCase)
export const createContentRequestSchema = z.object({
  projectId: z.string().uuid("Project ID must be a valid UUID"),
  postType: z.string().min(1, "Post type is required"),
  advice: z.string().optional(),
  benefit: z.string().optional(),
  platform: z.string().min(1, "Platform is required"),
  tone: z.string().min(1, "Tone is required"),
  length: z.string().min(1, "Length is required"),
  useEmojis: z.boolean().default(false),
  useHashtags: z.boolean().default(false),
});

// Type for frontend request
export type CreateContentRequest = z.infer<typeof createContentRequestSchema>;

// Type for database insert (snake_case)
export interface ContentDbInsert {
  project_id: string;
  post_type: string;
  advice?: string;
  benefit?: string;
  platform: string;
  tone: string;
  length: string;
  use_emojis: boolean;
  use_hashtags: boolean;
  content?: string;
  status: string;
  created_at: string;
}

// Type for database response (snake_case)
export interface ContentDbResponse {
  id: number;
  project_id: string;
  post_type: string;
  advice?: string;
  benefit?: string;
  platform: string;
  tone: string;
  length: string;
  use_emojis: boolean;
  use_hashtags: boolean;
  content?: string;
  status: string;
  created_at: string;
  updated_at?: string;
}

// Type for API response (camelCase)
export interface ContentResponse {
  id: number;
  projectId: string;
  postType: string;
  advice?: string;
  benefit?: string;
  platform: string;
  tone: string;
  length: string;
  useEmojis: boolean;
  useHashtags: boolean;
  content?: string;
  status: string;
  createdAt: string;
  updatedAt?: string;
}

// Convert from camelCase request to snake_case database format
export function toDbFormat(
  requestData: CreateContentRequest
): Omit<ContentDbInsert, "content" | "status" | "created_at"> {
  return {
    project_id: requestData.projectId,
    post_type: requestData.postType,
    advice: requestData.advice,
    benefit: requestData.benefit,
    platform: requestData.platform,
    tone: requestData.tone,
    length: requestData.length,
    use_emojis: requestData.useEmojis,
    use_hashtags: requestData.useHashtags,
  };
}

// Convert from snake_case database response to camelCase API response
export function toResponseFormat(dbData: ContentDbResponse): ContentResponse {
  return {
    id: dbData.id,
    projectId: dbData.project_id,
    postType: dbData.post_type,
    advice: dbData.advice,
    benefit: dbData.benefit,
    platform: dbData.platform,
    tone: dbData.tone,
    length: dbData.length,
    useEmojis: dbData.use_emojis,
    useHashtags: dbData.use_hashtags,
    content: dbData.content,
    status: dbData.status,
    createdAt: dbData.created_at,
    updatedAt: dbData.updated_at,
  };
}
