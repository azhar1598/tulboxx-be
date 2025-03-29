// utils/pdfGenerator.ts
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";

export async function generateInvoicePDF(invoice: any): Promise<Buffer> {
  const pdfDoc = await PDFDocument.create();
  const page = pdfDoc.addPage([595.28, 841.89]); // A4 size
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

  // Set font size and line height
  const fontSize = 12;
  const lineHeight = 20;

  // Company info
  page.drawText("Your Company Name", {
    x: 50,
    y: 800,
    font: boldFont,
    size: 16,
  });
  page.drawText("123 Business St, Suite 101", {
    x: 50,
    y: 780,
    font,
    size: fontSize,
  });
  page.drawText("Business City, State 12345", {
    x: 50,
    y: 760,
    font,
    size: fontSize,
  });

  // Invoice details
  page.drawText(`INVOICE #${invoice.invoice_number}`, {
    x: 400,
    y: 800,
    font: boldFont,
    size: 16,
  });
  page.drawText(`Issue Date: ${invoice.issue_date}`, {
    x: 400,
    y: 780,
    font,
    size: fontSize,
  });
  page.drawText(`Due Date: ${invoice.due_date}`, {
    x: 400,
    y: 760,
    font,
    size: fontSize,
  });

  // Customer info
  page.drawText("Bill To:", { x: 50, y: 720, font: boldFont, size: fontSize });
  page.drawText(invoice.customer_name, { x: 50, y: 700, font, size: fontSize });
  page.drawText(invoice.email, { x: 50, y: 680, font, size: fontSize });
  page.drawText(invoice.phone, { x: 50, y: 660, font, size: fontSize });
  page.drawText(invoice.address, { x: 50, y: 640, font, size: fontSize });

  // Line items header
  page.drawText("Description", {
    x: 50,
    y: 600,
    font: boldFont,
    size: fontSize,
  });
  page.drawText("Quantity", { x: 300, y: 600, font: boldFont, size: fontSize });
  page.drawText("Price", { x: 400, y: 600, font: boldFont, size: fontSize });
  page.drawText("Total", { x: 500, y: 600, font: boldFont, size: fontSize });

  // Line separator
  page.drawLine({
    start: { x: 50, y: 590 },
    end: { x: 550, y: 590 },
    thickness: 1,
    color: rgb(0, 0, 0),
  });

  // Line items
  let y = 570;
  for (const item of invoice.line_items) {
    page.drawText(item.description, { x: 50, y, font, size: fontSize });
    page.drawText(item.quantity.toString(), {
      x: 300,
      y,
      font,
      size: fontSize,
    });
    page.drawText(`$${item.unitPrice.toFixed(2)}`, {
      x: 400,
      y,
      font,
      size: fontSize,
    });
    page.drawText(`$${item.totalPrice.toFixed(2)}`, {
      x: 500,
      y,
      font,
      size: fontSize,
    });
    y -= lineHeight;
  }

  // Total
  page.drawLine({
    start: { x: 400, y: y - 10 },
    end: { x: 550, y: y - 10 },
    thickness: 1,
    color: rgb(0, 0, 0),
  });
  page.drawText("Total:", {
    x: 400,
    y: y - 30,
    font: boldFont,
    size: fontSize,
  });
  page.drawText(`$${invoice.invoice_total_amount.toFixed(2)}`, {
    x: 500,
    y: y - 30,
    font: boldFont,
    size: fontSize,
  });

  // Footer
  y -= 80;
  page.drawText("Payment Information:", {
    x: 50,
    y,
    font: boldFont,
    size: fontSize,
  });
  page.drawText(
    invoice.remit_payment || "Please contact us for payment details.",
    { x: 50, y: y - 20, font, size: fontSize }
  );

  if (invoice.additional_notes) {
    y -= 60;
    page.drawText("Notes:", { x: 50, y, font: boldFont, size: fontSize });
    page.drawText(invoice.additional_notes, {
      x: 50,
      y: y - 20,
      font,
      size: fontSize,
    });
  }

  // Save PDF
  const pdfBytes = await pdfDoc.save();
  return Buffer.from(pdfBytes);
}
