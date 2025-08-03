import express from "express";
import cors from "cors";
import swaggerDocs from "./utils/swagger";
import { protectedRoutes, publicRoutes, authRoutes } from "./routes";
import scalarAPISpec from "./utils/scalar";

const app = express();

const allowedOrigins = [
  "http://localhost:3000", // Local dev
  "https://tulboxx.vercel.app", // Deployed frontend
  "https://app.tulboxx.com",
  "https://tulboxx.com",
];

// app.use(cors({ origin: "http://localhost:3000", credentials: true }));
app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error("Not allowed by CORS"));
      }
    },
    credentials: true,
  })
);

app.use(express.json());

app.get("/", (req, res) => {
  res.send("I am running! 🎉");
});

app.use("/", protectedRoutes);
app.use("/public", publicRoutes);
app.use("/auth", authRoutes);

const PORT = process.env.PORT || 3001;

app.get("/docs", (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>API Reference</title>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body>
        <script
          id="api-reference"
          data-url="/openapi.json"
          src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
      </body>
    </html>
  `);
});

app.get("/openapi.json", (req, res) => {
  res.json(scalarAPISpec);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Swagger Docs available at http://localhost:${PORT}/docs`);
  swaggerDocs(app, PORT);
});

export default app;
