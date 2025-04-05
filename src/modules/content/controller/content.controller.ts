// import { Request, Response } from "express";
// import { ContentService } from "../service/content.service";
// import { CreateContentRequest } from "../dto/create-content.dto";

// export class ContentController {
//   private service: ContentService;

//   constructor() {
//     this.service = new ContentService();
//   }

//   async create(req: Request, res: Response): Promise<void> {
//     try {
//       const request = req.body as CreateContentRequest;
//       const content = await this.service.createContent(request);
//       res.status(201).json(content);
//     } catch (error: any) {
//       res.status(500).json({ message: error.message });
//     }
//   }

//   async getById(req: Request, res: Response): Promise<void> {
//     try {
//       const id = Number(req.params.id);
//       const content = await this.service.getContentById(id);

//       if (!content) {
//         res.status(404).json({ message: "Content not found" });
//         return;
//       }

//       res.json(content);
//     } catch (error: any) {
//       res.status(500).json({ message: error.message });
//     }
//   }

//   async getByProjectId(req: Request, res: Response): Promise<void> {
//     try {
//       const projectId = req.params.projectId;
//       const page = Number(req.query.page) || 1;
//       const limit = Number(req.query.limit) || 10;

//       const result = await this.service.getContentsByProjectId(projectId, {
//         page,
//         limit,
//       });
//       res.json(result);
//     } catch (error: any) {
//       res.status(500).json({ message: error.message });
//     }
//   }

//   // async update(req: Request, res: Response): Promise<void> {
//   //   try {
//   //     const id = Number(req.params.id);
//   //     const request = req.body as UpdateContentRequest;
//   //     const content = await this.service.updateContent(id, request);
//   //     res.json(content);
//   //   } catch (error) {
//   //     res.status(500).json({ message: error.message });
//   //   }
//   // }

//   async generate(req: Request, res: Response): Promise<void> {
//     try {
//       const id = Number(req.params.id);
//       const content = await this.service.generateContent(id);
//       res.json(content);
//     } catch (error: any) {
//       res.status(500).json({ message: error.message });
//     }
//   }

//   async delete(req: Request, res: Response): Promise<void> {
//     try {
//       const id = Number(req.params.id);
//       await this.service.deleteContent(id);
//       res.status(204).send();
//     } catch (error: any) {
//       res.status(500).json({ message: error.message });
//     }
//   }
// }
