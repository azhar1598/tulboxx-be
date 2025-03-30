import { ContentRepository } from "../repository/content.repository";
import { ContentModel } from "../model/content.model";
import {
  ContentResponse,
  CreateContentRequest,
  toResponseFormat,
  // UpdateContentRequest,
  // ContentResponse,
  // toResponseFormat,
} from "../dto/create-content.dto";
import { PaginationOptions, PaginatedResponse } from "@/types/pagination";

export class ContentService {
  private repository: ContentRepository;

  constructor() {
    this.repository = new ContentRepository();
  }

  async createContent(request: CreateContentRequest): Promise<ContentResponse> {
    const content = await this.repository.create(request);
    return toResponseFormat(content);
  }

  async getContentById(id: number): Promise<ContentResponse | null> {
    const content = await this.repository.findById(id);
    return content ? toResponseFormat(content) : null;
  }

  async getContentsByProjectId(
    projectId: string,
    options: PaginationOptions
  ): Promise<PaginatedResponse<ContentResponse>> {
    const result = await this.repository.findByProjectId(projectId, options);

    return {
      ...result,
      data: result.data.map((content) => toResponseFormat(content)),
    };
  }

  // async updateContent(
  //   id: number,
  //   request: UpdateContentRequest
  // ): Promise<ContentResponse> {
  //   const content = await this.repository.update(id, request);
  //   return toResponseFormat(content);
  // }

  async generateContent(id: number): Promise<ContentResponse> {
    const content = await this.repository.findById(id);
    if (!content) {
      throw new Error("Content not found");
    }

    // Here you would call an AI service or similar to generate content
    // For this example, we'll just set some placeholder content
    const generatedText = `Generated content for ${content.post_type} on ${content.platform}`;

    const updatedContent = await this.repository.update(id, {
      content: generatedText,
      status: "generated",
    });

    return toResponseFormat(updatedContent);
  }

  async deleteContent(id: number): Promise<void> {
    await this.repository.delete(id);
  }
}
