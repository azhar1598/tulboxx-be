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

export async function sendEmail() {
  const mailOptions = {
    from: "mohammedazhar.1598@gmail.com",
    to: "azhar11226a@gmail.com",
    subject: `Invoice from Your Company Name`,
    text: "Hello World",
  };
  transporter.sendMail(mailOptions, function (error: any, info: any) {
    if (error) {
      console.log(error);
    } else {
      console.log("Email Send " + info.response);
    }
  });
}

// Add this function to your codebase
// export async function sendInvoiceEmail(invoice: any, pdfBuffer: Buffer) {
//   // Create email content
//   const emailContent = `
//       <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
//         <h2>Invoice #${invoice.invoice_number}</h2>
//         <p>Dear ${invoice.customer_name},</p>
//         <p>Please find attached your invoice #${
//           invoice.invoice_number
//         } for the amount of $${invoice.invoice_total_amount.toFixed(2)}.</p>
//         <p>Invoice Date: ${invoice.issue_date}</p>
//         <p>Due Date: ${invoice.due_date}</p>
//         <p>If you have any questions regarding this invoice, please don't hesitate to contact us.</p>
//         <p>Thank you for your business!</p>
//         <p>Best regards,<br>Your Company Name</p>
//       </div>
//     `;

//   // Setup email options with attachment
//   const mailOptions = {
//     from: "mohammedazhar.1598@gmail.com",
//     to: invoice.email,
//     subject: `Invoice #${invoice.invoice_number} from Your Company Name`,
//     html: emailContent,
//     // attachments: [
//     //   {
//     //     filename: `Invoice-${invoice.invoice_number}.pdf`,
//     //     content: pdfBuffer,
//     //     contentType: "application/pdf",
//     //   },
//     // ],
//   };

//   // Send email with attachment
//   return new Promise((resolve, reject) => {
//     transporter.sendMail(mailOptions, function (error: any, info: any) {
//       if (error) {
//         console.log("Error sending invoice email:", error);
//         reject(error);
//       } else {
//         console.log("Invoice email sent:", info.response);
//         resolve(info);
//       }
//     });
//   });
// }
