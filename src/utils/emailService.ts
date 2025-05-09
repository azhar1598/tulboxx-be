import { supabase } from "../supabaseClient";
import dayjs from "dayjs";
import nodejsmailer from "nodemailer";

var transporter = nodejsmailer.createTransport({
  service: "gmail",
  secure: true,
  host: "smtp.gmail.com",
  port: 465,
  auth: {
    user: "mohammedazhar.1598@gmail.com",
    pass: "afixxnfiupnrpknz",
  },
});

export async function sendEmail(invoiceData: any) {
  const client = await supabase
    .from("clients")
    .select("*")
    .eq("id", invoiceData.client_id)
    .single();
  const project = await supabase
    .from("estimates")
    .select("*")
    .eq("id", invoiceData.project_id)
    .single();
  const mailOptions = {
    from: "mohammedazhar.1598@gmail.com",
    to: client.data?.email,
    subject: "Invoice from Tuboxx",
    html: `
    <div style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 5px;">
      <div style="text-align: center; padding-bottom: 20px; border-bottom: 1px solid #eee;">
        <h2 style="color: #007bff; margin-bottom: 5px;">Invoice from Tulboxx</h2>
        <p style="color: #6c757d; font-size: 14px;">#${
          project.data?.projectName || ""
        }</p>
      </div>
      
  <div style="display:flex;justify-content:space-between;padding: 20px 0;">
     <div style="width: 40%;">   
     <p>Dear ${client.data?.name || "Customer"},</p>
        <p>Thank you for your business. Please find your invoice details below.</p>
        </div>
       
      </div>
      
      <div style="display: flex; justify-content: space-between; margin-bottom: 20px;">
        <div style="width: 48%;">
          <h4 style="color: #007bff; margin-bottom: 10px;">BILLED TO:</h4>
          <p style="margin: 0;">${client.data?.name || ""}</p>
          <p style="margin: 0;">${client.data?.address || ""}</p>
          <p style="margin: 0;"><strong>Phone:</strong> ${
            client.data?.phone || ""
          }</p>
          <p style="margin: 0;"><strong>Email:</strong> ${
            client.data?.email || ""
          }</p>
        </div>
        <div style="width: 48%;">
          <h4 style="color: #007bff; margin-bottom: 10px;">INVOICE INFO:</h4>
          <p style="margin: 0;"><strong>Issue Date:</strong> ${
            dayjs(invoiceData.issueDate).format("DD-MM-YYYY") || ""
          }</p>
          <p style="margin: 0;"><strong>Due Date:</strong> ${
            dayjs(invoiceData.dueDate).format("DD-MM-YYYY") || ""
          }</p>
          <p style="margin: 0;"><strong>Project Name:</strong> ${
            project.data?.projectName || ""
          }</p>
        </div>
      </div>
      
      <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
        <tr style="background-color: #f8f9fa;">
          <th style="border: 1px solid #ddd; padding: 8px; text-align: left;">Item</th>
          <th style="border: 1px solid #ddd; padding: 8px; text-align: right;">Quantity</th>
          <th style="border: 1px solid #ddd; padding: 8px; text-align: right;">Price</th>
          <th style="border: 1px solid #ddd; padding: 8px; text-align: right;">Amount</th>
        </tr>
        
        ${
          invoiceData.line_items && Array.isArray(invoiceData.line_items)
            ? invoiceData.line_items
                .map(
                  (item: any) => `
            <tr>
              <td style="border: 1px solid #ddd; padding: 8px;">${
                item.description || "Item"
              }</td>
              <td style="border: 1px solid #ddd; padding: 8px; text-align: right;">${
                item.quantity || "1"
              }</td>
              <td style="border: 1px solid #ddd; padding: 8px; text-align: right;">$${
                item.unitPrice || "0.00"
              }</td>
              <td style="border: 1px solid #ddd; padding: 8px; text-align: right;">$${
                item.totalPrice || item.quantity * item.unitPrice || "0.00"
              }</td>
            </tr>
          `
                )
                .join("")
            : `<tr>
            <td style="border: 1px solid #ddd; padding: 8px;">Product 1</td>
            <td style="border: 1px solid #ddd; padding: 8px; text-align: right;">1</td>
            <td style="border: 1px solid #ddd; padding: 8px; text-align: right;">$100</td>
            <td style="border: 1px solid #ddd; padding: 8px; text-align: right;">$100</td>
          </tr>`
        }
        
        <tr>
          <td colspan="3" style="border: 1px solid #ddd; padding: 8px; text-align: right; font-weight: bold;">Grand Total:</td>
          <td style="border: 1px solid #ddd; padding: 8px; text-align: right; font-weight: bold;">$${
            invoiceData.invoice_total_amount || "Null"
          }</td>
        </tr>
      </table>
      
      ${
        invoiceData.invoice_summary
          ? `
        <div style="margin-bottom: 20px;">
          <h4 style="color: #007bff;">INVOICE SUMMARY</h4>
          <p>${invoiceData.invoice_summary}</p>
        </div>
      `
          : ""
      }
      
      ${
        invoiceData.remit_payment
          ? `
        <div style="margin-bottom: 20px;">
          <h4 style="color: #007bff;">PAYMENT INFORMATION</h4>
        </div>
        <p>Please make all payments to the following bank account:</p>
        <p>Account Name: ${invoiceData.remit_payment.accountName}</p>
        <p>Account Number: ${invoiceData.remit_payment.accountNumber}</p>
        <p>Routing Number: ${invoiceData.remit_payment.routingNumber}</p>
        <p>Tax ID: ${invoiceData.remit_payment.taxId}</p>
      `
          : ""
      }
      
      ${
        invoiceData.additional_notes
          ? `
        <div style="margin-bottom: 20px;">
          <h4 style="color: #007bff;">ADDITIONAL NOTES</h4>
          <p>${invoiceData.additional_notes}</p>
        </div>
      `
          : ""
      }
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
        <p>If you have any questions about this invoice, please contact us.</p>
        <p>Best Regards,<br>Tulboxx</p>
      </div>
    </div>
  `,
  };

  transporter.sendMail(mailOptions, function (error: any, info: any) {
    if (error) {
      console.log(error);
    } else {
      console.log("Email Sent: " + info.response);
    }
  });
}
