import { GoogleGenerativeAI } from "@google/generative-ai";

export class ExternalApiService {
  private genAI: GoogleGenerativeAI;

  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
  }

  async fetchYoutubeVideo(businessName: string): Promise<string> {
    const response = await fetch(
      `https://www.googleapis.com/youtube/v3/search?part=snippet&q=${encodeURIComponent(
        businessName
      )}-business&maxResults=1&type=video&key=${process.env.YOUTUBE_API_KEY}`
    );
    const data: any = await response.json();
    const videoId = data.items?.[0]?.id?.videoId || "";
    return videoId ? `https://www.youtube.com/embed/${videoId}` : "";
  }

  async fetchPexelsImage(businessName: string): Promise<string> {
    const response = await fetch(
      `https://api.pexels.com/v1/search?query=${encodeURIComponent(
        businessName
      )}&per_page=1`,
      {
        headers: {
          Authorization: process.env.PEXELS_API_KEY!,
        },
      }
    );
    const data: any = await response.json();
    return data.photos?.[0]?.src?.medium || "";
  }

  async generateBusinessInsights(businessName: string): Promise<string> {
    const model = this.genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const prompt = `Provide detailed business realistic insights and pricing should start as cheap as possible for a ${decodeURIComponent(
      businessName.replace(/\s+/g, " ")
    )} business in India. the budget should start from very minimum and cheap estimation to get started.
        Create only a structured JSON response with the following details:
        {
          businessName:"short hand Business name"
          "initialInvestment": {
            "startupCost": "Range in ₹",
            "monthlyOperationalCost": "Range in ₹"
          },
          "requiredEquipment": [
            {
              "item": "Equipment name",
              "estimatedCost": "Cost range in ₹",
              "searchKeyword": "Amazon search keyword for the item"
            }
          ],
          "locationStrategy": {
            "bestLocations": ["Location 1", "Location 2"],
            "footTraffic": "Description",
            "competition": "Description"
          },
          "licenses": [
            "License 1",
            "License 2"
          ],
          "revenuePotential": {
            "dailySales": "Range in ₹",
            "monthlySales": "Range in ₹"
          },
          "digitalServices": [
            {
              "service": "Service name",
              "estimatedCost": "Cost in ₹"
            }
          ],
          "youtubeVideo":"",
          "businessThumbnail":""
        }
        Ensure the response is a valid JSON object that can be directly parsed.`;
    const result = await model.generateContent(prompt);
    return result.response.text();
  }
}
