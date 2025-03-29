const scalarAPISpec: any = {
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
      post: {
        tags: ["Estimates"],
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  projectName: {
                    type: "string",
                    minLength: 1,
                  },
                  customerName: {
                    type: "string",
                    minLength: 1,
                  },
                  email: {
                    type: "string",
                    format: "email",
                  },
                  phone: {
                    type: "string",
                  },
                  address: {
                    type: "string",
                  },
                  type: {
                    type: "string",
                    enum: ["residential", "commercial"],
                  },
                  serviceType: {
                    type: "string",
                  },
                  problemDescription: {
                    type: "string",
                  },
                  solutionDescription: {
                    type: "string",
                  },
                  projectEstimate: {
                    type: "string",
                  },
                  projectStartDate: {
                    type: "string",
                    format: "date",
                  },
                  projectEndDate: {
                    type: "string",
                    format: "date",
                  },
                  lineItems: {
                    type: "array",
                    items: {
                      $ref: "#/components/schemas/lineItemSchema",
                    },
                  },
                  equipmentMaterials: {
                    type: "string",
                  },
                  additionalNotes: {
                    type: "string",
                  },
                },
                required: [
                  "projectName",
                  "customerName",
                  "email",
                  "type",
                  "serviceType",
                  "problemDescription",
                  "solutionDescription",
                  "projectEstimate",
                  "projectStartDate",
                  "projectEndDate",
                  "lineItems",
                ],
              },
            },
          },
        },
      },
    },
    "/estimates": {
      get: {
        tags: ["Estimates"],
      },
      post: {
        tags: ["Estimates"],
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  projectName: {
                    type: "string",
                    minLength: 1,
                  },
                  customerName: {
                    type: "string",
                    minLength: 1,
                  },
                  email: {
                    type: "string",
                    format: "email",
                  },
                  phone: {
                    type: "string",
                  },
                  address: {
                    type: "string",
                  },
                  type: {
                    type: "string",
                    enum: ["residential", "commercial"],
                  },
                  serviceType: {
                    type: "string",
                  },
                  problemDescription: {
                    type: "string",
                  },
                  solutionDescription: {
                    type: "string",
                  },
                  projectEstimate: {
                    type: "string",
                  },
                  projectStartDate: {
                    type: "string",
                    format: "date",
                  },
                  projectEndDate: {
                    type: "string",
                    format: "date",
                  },
                  lineItems: {
                    type: "array",
                    items: {
                      $ref: "#/components/schemas/lineItemSchema",
                    },
                  },
                  equipmentMaterials: {
                    type: "string",
                  },
                  additionalNotes: {
                    type: "string",
                  },
                },
                required: [
                  "projectName",
                  "customerName",
                  "email",
                  "type",
                  "serviceType",
                  "problemDescription",
                  "solutionDescription",
                  "projectEstimate",
                  "projectStartDate",
                  "projectEndDate",
                  "lineItems",
                ],
              },
            },
          },
        },
      },
    },
    "/estimates/:id": {
      get: {
        tags: ["Estimates"],
        summary: "Get estimate by id",
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            type: "string",
          },
        ],
        responses: {
          200: {
            description: "Estimate found",
          },
        },
      },
    },
    components: {
      schemas: {
        lineItemSchema: {
          type: "object",
          properties: {
            description: {
              type: "string",
            },
            quantity: {
              type: "integer",
            },
            unitPrice: {
              type: "number",
            },
            totalPrice: {
              type: "number",
            },
          },
          required: ["description", "quantity", "unitPrice", "totalPrice"],
        },
      },
    },
  },

  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      },
    },
  },

  apis: ["src/routes/*.ts"],
};

export default scalarAPISpec;
