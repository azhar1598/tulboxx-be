import { Request, Response } from "express";
import { supabase } from "../supabaseClient";
import { z } from "zod";
import { generateInvoicePDF } from "../utils/pdfGenerator";
import { sendEmail } from "../utils/emailService";
import { MailgunService } from "../utils/mailgunService";
// import { sendInvoiceEmail } from "../utils/emailService";

// Define the schema for validation
const lineItemSchema = z.object({
  id: z.number(),
  description: z.string(),
  quantity: z.number(),
  unitPrice: z.number(),
  totalPrice: z.number(),
});

const remitPaymentSchema = z.object({
  accountName: z.string(),
  accountNumber: z.string(),
  routingNumber: z.string(),
  taxId: z.string(),
});

const invoiceSchema = z.object({
  // General information
  customerName: z.string().min(1, "Customer name is required"),
  email: z.string().email("Invalid email format"),
  phone: z.string().optional(),
  address: z.string().optional(),

  // Invoice details
  issueDate: z.string(), // Store as ISO string
  dueDate: z.string().nullable(),
  invoiceTotalAmount: z.number(),
  lineItems: z.array(lineItemSchema),
  invoiceSummary: z.string(),

  // Payment details
  remitPayment: remitPaymentSchema,

  // Optional: Additional fields
  additionalNotes: z.string().optional(),
  projectId: z.string().optional(), // Add this field
  projectName: z.string(),
  user_id: z.string(),
});

export class InvoicesController {
  // async getInvoices(req: Request, res: Response) {
  //   try {
  //     // Extract pagination parameters from query
  //     const page = parseInt(req.query.page as string) || 1;
  //     const limit = parseInt(req.query.limit as string) || 20;
  //     const startIndex = (page - 1) * limit;

  //     // First, get the total count of records
  //     const { count, error: countError } = await supabase
  //       .from("invoices")
  //       .select("*", { count: "exact", head: true });

  //     if (countError) throw countError;

  //     // Then fetch the paginated data with project name from estimates
  //     // const { data, error } = await supabase
  //     //   .from("invoices")
  //     //   .select(
  //     //     `
  //     //     *,
  //     //     estimates!project_id (
  //     //       projectName
  //     //     )
  //     //   `
  //     //   )
  //     //   .range(startIndex, startIndex + limit - 1);

  //     const { data, error } = await supabase
  //       .from("invoices")
  //       .select("*")

  //       .range(startIndex, startIndex + limit - 1);

  //     if (error) throw error;

  //     // Transform the data to include project_name at the top level
  //     const transformedData = data?.map((invoice) => ({
  //       ...invoice,
  //       project_name: invoice.estimates?.project_name || null,
  //     }));

  //     // Calculate pagination metadata
  //     const totalRecords = count || 0;
  //     const totalPages = Math.ceil(totalRecords / limit);

  //     // Prepare the response with data and metadata
  //     const response = {
  //       data: transformedData,
  //       metadata: {
  //         totalRecords,
  //         recordsPerPage: limit,
  //         currentPage: page,
  //         totalPages,
  //         hasNextPage: page < totalPages,
  //         hasPreviousPage: page > 1,
  //       },
  //     };

  //     return res.status(200).json(response);
  //   } catch (error) {
  //     console.error("Error fetching invoices:", error);
  //     return res.status(500).json({ error: "Failed to fetch invoices" });
  //   }
  // }

  async getInvoices(req: Request, res: Response) {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;
      const startIndex = (page - 1) * limit;

      const status = req.query.status as string | undefined;
      const search = req.query.search as string | undefined;

      const user_id = req.user?.id;
      if (!user_id) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Count query
      let countQuery = supabase
        .from("invoices")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user_id);

      if (status) {
        countQuery = countQuery.eq("status", status);
      }

      if (search) {
        countQuery = countQuery.or(
          `invoice_number.ilike.%${search}%,customer_name.ilike.%${search}%`
        );
      }

      const { count, error: countError } = await countQuery;
      if (countError) throw countError;

      // Data query
      let dataQuery = supabase
        .from("invoices")
        .select("*")
        .eq("user_id", user_id)
        .range(startIndex, startIndex + limit - 1);

      if (status) {
        dataQuery = dataQuery.eq("status", status);
      }

      if (search) {
        dataQuery = dataQuery.or(
          `invoice_number.ilike.%${search}%,customer_name.ilike.%${search}%`
        );
      }

      const { data, error } = await dataQuery;
      if (error) throw error;

      const totalRecords = count || 0;
      const totalPages = Math.ceil(totalRecords / limit);

      return res.status(200).json({
        data,
        metadata: {
          totalRecords,
          recordsPerPage: limit,
          currentPage: page,
          totalPages,
          hasNextPage: page < totalPages,
          hasPreviousPage: page > 1,
        },
      });
    } catch (error) {
      console.error("Error fetching invoices:", error);
      return res.status(500).json({ error: "Failed to fetch invoices" });
    }
  }

  async createInvoice(req: Request, res: Response) {
    try {
      const validationResult = invoiceSchema.safeParse(req.body);

      if (!validationResult.success) {
        return res.status(400).json({
          error: "Validation failed",
          details: validationResult.error.format(),
        });
      }

      const invoiceData = validationResult.data;

      // Verify the total amount matches the sum of line items
      const calculatedTotal = invoiceData.lineItems.reduce(
        (sum, item) => sum + item.totalPrice,
        0
      );

      if (Math.abs(calculatedTotal - invoiceData.invoiceTotalAmount) > 0.01) {
        return res.status(400).json({
          error: "Invoice total doesn't match line items sum",
          expected: calculatedTotal,
          received: invoiceData.invoiceTotalAmount,
        });
      }

      const generateInvoiceNumber = () => {
        const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let result = "";
        for (let i = 0; i < 5; i++) {
          result += characters.charAt(
            Math.floor(Math.random() * characters.length)
          );
        }
        return result;
      };

      // Generate invoice number
      const invoiceNumber = generateInvoiceNumber();

      // Add metadata
      // Add this transformation before inserting
      const transformToDatabaseFormat = (data: any) => {
        return {
          customer_name: data.customerName,
          email: data.email,
          phone: data.phone,
          address: data.address,
          issue_date: data.issueDate,
          due_date: data.dueDate,
          invoice_total_amount: data.invoiceTotalAmount,
          line_items: data.lineItems,
          invoice_summary: data.invoiceSummary,
          remit_payment: data.remitPayment,
          additional_notes: data.additionalNotes,
          project_id: data.projectId || null, // Corrected field name
        };
      };

      // Then use it in your createInvoice method
      const dataToInsert = {
        ...transformToDatabaseFormat(invoiceData),
        invoice_number: invoiceNumber,
        created_at: new Date().toISOString(),
        status: "unpaid",
        user_id: invoiceData.user_id,
      };

      // Insert into database
      const { data, error } = await supabase
        .from("invoices")
        .insert(dataToInsert)
        .select();

      if (error) throw error;

      try {
        // Generate PDF invoice
        // const pdfBuffer = await generateInvoicePDF(data[0]);

        // Send email with invoice attached

        // console.log("Sending email with invoice attached", data[0]);
        // await sendInvoiceEmail(data[0], "pdfBuffer");
        await sendEmail(invoiceData);
        // await MailgunService();
        return res.status(201).json({
          message: "Invoice created successfully and email sent",
          invoice: data[0],
        });
      } catch (emailError) {
        // If email fails, still return success for invoice creation
        console.error("Error sending invoice email:", emailError);

        return res.status(201).json({
          message: "Invoice created successfully but failed to send email",
          invoice: data[0],
        });
      }
    } catch (error: any) {
      console.error("Error creating invoice:", error);
      return res.status(500).json({
        error: "Failed to create invoice",
        details: error.message,
      });
    }
  }

  async getInvoiceById(req: Request, res: Response) {
    try {
      const { id } = req.params;

      const { data, error } = await supabase
        .from("invoices")
        .select("*")
        .eq("id", id)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "Invoice not found" });
        }
        throw error;
      }

      return res.status(200).json(data);
    } catch (error) {
      console.error("Error fetching invoice:", error);
      return res.status(500).json({ error: "Failed to fetch invoice" });
    }
  }

  async updateInvoiceStatus(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const { status } = req.body;

      // Validate status
      if (!["unpaid", "paid", "overdue", "cancelled"].includes(status)) {
        return res.status(400).json({
          error: "Invalid status",
          message: "Status must be one of: unpaid, paid, overdue, cancelled",
        });
      }

      const { data, error } = await supabase
        .from("invoices")
        .update({ status, updated_at: new Date().toISOString() })
        .eq("id", id)
        .select();

      if (error) {
        if (error.code === "PGRST116") {
          return res.status(404).json({ error: "Invoice not found" });
        }
        throw error;
      }

      return res.status(200).json({
        message: "Invoice status updated successfully",
        invoice: data[0],
      });
    } catch (error) {
      console.error("Error updating invoice status:", error);
      return res.status(500).json({ error: "Failed to update invoice status" });
    }
  }

  async deleteInvoice(req: Request, res: Response) {
    try {
      const { id } = req.params;

      // First check if the invoice exists
      const { data: invoice, error: fetchError } = await supabase
        .from("invoices")
        .select("id")
        .eq("id", id)
        .single();

      if (fetchError) {
        if (fetchError.code === "PGRST116") {
          return res.status(404).json({ error: "Invoice not found" });
        }
        throw fetchError;
      }

      // Then delete the invoice
      const { error: deleteError } = await supabase
        .from("invoices")
        .delete()
        .eq("id", id);

      if (deleteError) throw deleteError;

      return res.status(200).json({
        message: "Invoice deleted successfully",
      });
    } catch (error) {
      console.error("Error deleting invoice:", error);
      return res.status(500).json({ error: "Failed to delete invoice" });
    }
  }
}
