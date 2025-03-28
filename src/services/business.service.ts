// import { BusinessInsights } from "../types/business.types";
import { BusinessInsights } from "@/types";
import { redis } from "../config/redis";
import { ExternalApiService } from "./external-api.service";

export class BusinessService {
  private externalApiService: ExternalApiService;
  private CACHE_EXPIRY = 60 * 60 * 24; // 24 hours

  constructor() {
    this.externalApiService = new ExternalApiService();
  }

  async getBusinessInsights(businessName: string): Promise<BusinessInsights> {
    // Check cache first
    const cachedData = await redis.get(`business:${businessName}`);
    if (cachedData) {
      return JSON.parse(cachedData);
    }

    // Fetch all required data in parallel
    const [insightsText, youtubeVideo, thumbnail] = await Promise.all([
      this.externalApiService.generateBusinessInsights(businessName),
      this.externalApiService.fetchYoutubeVideo(businessName),
      this.externalApiService.fetchPexelsImage(businessName),
    ]);

    // Parse and combine the data
    const insights: BusinessInsights = JSON.parse(
      insightsText.replace(/```json\n|```/g, "").trim()
    );
    insights.youtubeVideo = youtubeVideo;
    insights.businessThumbnail = thumbnail;

    // Cache the result
    await redis.setex(
      `business:${businessName}`,
      this.CACHE_EXPIRY,
      JSON.stringify(insights)
    );

    return insights;
  }
}
