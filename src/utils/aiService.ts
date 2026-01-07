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

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
  const models = [
    "gemini-flash-latest",
    "gemini-2.0-flash",
    "gemini-1.5-flash-latest",
    "gemini-pro-latest",
  ];
  let lastError: any;

  for (const modelName of models) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();
      if (text) {
        return text;
      }
    } catch (error) {
      lastError = error;
      console.error(
        `Error calling Gemini API with model ${modelName} for content generation:`,
        error
      );
    }
  }

  console.error(
    "All models failed to generate content. Last error:",
    lastError
  );
  throw new Error(
    "Failed to generate content with Gemini API after trying multiple models."
  );
}

export async function generateQuickEstimateWithGemini(estimateData: any) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error("Gemini API key is not configured");
  }

  const prompt = `
    Generate a professional and detailed project description for a quick estimate based on the following project information.
    The response should be a JSON object containing a project overview, scope of work, timeline, pricing details, and a total estimated cost.
    Do not include any extra text, explanations, or formatting—only return valid JSON.

    The JSON object must be in the following format:
    {
      "projectOverview": "string",
      "scopeOfWork": "string",
      "timeline": "string",
      "pricing": "string",
      "total_amount": number
    }

    Project Details:
    - Project Name: ${estimateData.projectName}
    - Project Type: ${estimateData.projectType}
    - Problem Description: ${estimateData.problemDescription}
    - Solution Description: ${estimateData.solutionDescription}
    - Additional Notes: ${estimateData.additionalNotes || "None"}
    ${
      estimateData.projectEstimate
        ? `- Customer's Estimated Budget: $${estimateData.projectEstimate}`
        : ""
    }
  `;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
  const models = [
    "gemini-flash-latest",
    "gemini-2.0-flash",
    "gemini-1.5-flash-latest",
    "gemini-pro-latest",
  ];
  let lastError: any;

  for (const modelName of models) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      if (text) {
        // Clean the response to ensure it's valid JSON
        const cleanedText = text
          .replace(/```json/g, "")
          .replace(/```/g, "")
          .trim();
        return JSON.parse(cleanedText);
      }
    } catch (error) {
      lastError = error;
      console.error(
        `Error calling Gemini API with model ${modelName} for quick estimate generation:`,
        error
      );
    }
  }

  console.error(
    "All models failed to generate quick estimate. Last error:",
    lastError
  );
  throw new Error(
    "Failed to generate quick estimate with Gemini API after trying multiple models."
  );
}

export async function generateEstimateWithGemini(estimateData: any) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error("Gemini API key is not configured");
  }

  const context = `
Generate a professional and detailed project description for an estimate document based on the following project information. 
The description should include:
1. A compelling project overview that highlights the value to the customer
2. A clear scope of work section with bullet points
3. A concise timeline section mentioning the project duration
4. A pricing section that presents the cost professionally

Format the response exactly like this example:
---
Project Overview
We are pleased to present this project estimate for your upcoming project. Our solution will effectively address your specific needs.

Scope of Work
- First scope item
- Second scope item
- Third scope item

Timeline
The project is expected to take X weeks for completion.

Pricing
The total cost for the project is $X. This pricing is all-inclusive with no hidden fees.
---

Use the provided project details to personalize each section. Be specific about the type of work, customer pain points, and proposed solutions.

please provide the data in json format with key as {projectOverview:"", scopeOfWork:"", timeline:"", pricing:""}. only 
the json format and nothing else. follow this json format strictly.
`;

  const startDate = new Date(estimateData.projectStartDate);
  const endDate = new Date(estimateData.projectEndDate);
  const durationDays = Math.ceil(
    (endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)
  );
  const durationWeeks = Math.ceil(durationDays / 7);

  const fullPrompt = `
      ${context}
      
      Project Details:
      - Project Name: ${estimateData.projectName}
      - Customer: ${estimateData.customerName}
      - Type: ${estimateData.type}
      - Service: ${estimateData.serviceType}
      - Problem: ${estimateData.problemDescription}
      - Solution: ${estimateData.solutionDescription}
      - Cost: $${estimateData.projectEstimate}
      - Duration: ${durationDays} days (${durationWeeks} weeks)
      - Materials: ${estimateData.equipmentMaterials}
      - Additional Notes: ${estimateData.additionalNotes}
    `;
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
  const models = [
    "gemini-flash-latest",
    "gemini-2.0-flash",
    "gemini-1.5-flash-latest",
    "gemini-pro-latest",
  ];
  let lastError: any;

  for (const modelName of models) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(fullPrompt);
      const response = await result.response;
      const text = response.text();
      if (text) {
        return text;
      }
    } catch (error) {
      lastError = error;
      console.error(
        `Error calling Gemini API with model ${modelName} for estimate generation:`,
        error
      );
    }
  }
  console.error(
    "All models failed to generate estimate. Last error:",
    lastError
  );
  throw new Error(
    "Failed to generate estimate with Gemini API after trying multiple models."
  );
}
