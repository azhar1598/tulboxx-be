import FormData from "form-data"; // form-data v4.0.1
import Mailgun from "mailgun.js"; // mailgun.js v11.1.0

export async function MailgunService() {
  const mailgun = new Mailgun(FormData);
  const mg = mailgun.client({
    username: "api",
    key: process.env.MAILGUN_API_KEY || "API_KEY",
    // When you have an EU-domain, you must specify the endpoint:
    // url: "https://api.eu.mailgun.net"
  });
  try {
    const data = await mg.messages.create(
      "sandbox679378be9d864175be1e33bab0d33b9a.mailgun.org",
      {
        from: "Mailgun Sandbox <postmaster@sandbox679378be9d864175be1e33bab0d33b9a.mailgun.org>",
        to: ["Azhar Mohammed <mohammedazhar.1598@gmail.com>"],
        subject: "Hello Azhar Mohammed",
        text: "Congratulations Azhar Mohammed, you just sent an email with Mailgun! You are truly awesome!",
      }
    );

    console.log(data); // logs response data
  } catch (error) {
    console.log(error); //logs any error
  }
}
