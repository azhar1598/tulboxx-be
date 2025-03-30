import { GoogleGenerativeAI } from "@google/generative-ai";

export async function generateContentWithGemini(contentData: any) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error("Gemini API key is not configured");
  }

  const prompt = `
    Create a social media post with the following specifications:
    - Type of post: ${contentData.postType}
    - Platform: ${contentData.platform}
    - Tone: ${contentData.tone}
    - Length: ${contentData.length}
    ${
      contentData.advice ? `- Key advice to include: ${contentData.advice}` : ""
    }
    ${
      contentData.benefit
        ? `- Key benefit to highlight: ${contentData.benefit}`
        : ""
    }
    ${
      contentData.useEmojis
        ? "- Include appropriate emojis"
        : "- Do not use emojis"
    }
    ${
      contentData.useHashtags
        ? "- Include relevant hashtags"
        : "- Do not use hashtags"
    }
    Generate a JSON object for a social media post based on the above specifications. 
    Do NOT include any extra text, explanations, or formatting—only return valid JSON.

    The JSON object should be in the following format:
    {
      "content": "string",
      "title": "string",
      "visual_content_idea": "string",     
    }

  `;

  try {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const result = await model.generateContent(prompt);
    const response = await result.response;
    return response.text();
  } catch (error) {
    console.error("Error calling Gemini API:", error);
    throw new Error("Failed to generate content with Gemini API");
  }
}
