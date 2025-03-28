const scalarAPISpec = {
  openapi: "3.0.0",
  info: {
    title: "My API",
    version: "1.0.0",
    description: "API documentation using Scalar",
  },
  servers: [
    {
      url: "http://localhost:3001",
      description: "Local development server",
    },
  ],
  paths: {
    "/": {
      get: {
        summary: "Root endpoint",
        responses: {
          "200": {
            description: "Successful response",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    message: {
                      type: "string",
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
    "/public/estimates": {
      get: {
        tags: ["Estimates"],
      },
    },
  },
  //   components: {
  //     securitySchemes: {
  //       bearerAuth: {
  //         type: "http",
  //         scheme: "bearer",
  //         bearerFormat: "JWT",
  //       },
  //     },
  //   },
  security: [{ bearerAuth: [] }],
  apis: ["src/routes/*.ts"],
};

export default scalarAPISpec;
