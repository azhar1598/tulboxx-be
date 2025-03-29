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
    subject: "Invoice from Your Company Name",
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px;">
        <h2 style="color: #007bff;">Invoice from Your Company</h2>
        <p>Dear Customer,</p>
        <p>Thank you for your purchase. Please find your invoice details below.</p>
        <table style="width: 100%; border-collapse: collapse; margin-top: 10px;">
          <tr>
            <th style="border: 1px solid #ddd; padding: 8px;">Item</th>
            <th style="border: 1px solid #ddd; padding: 8px;">Price</th>
          </tr>
          <tr>
            <td style="border: 1px solid #ddd; padding: 8px;">Product 1</td>
            <td style="border: 1px solid #ddd; padding: 8px;">$100</td>
          </tr>
        </table>
        <p style="margin-top: 10px;">Total: <strong>$100</strong></p>
        <p>Best Regards,<br>Your Company</p>
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
