export interface BusinessInsights {
  businessName: string;
  initialInvestment: {
    startupCost: string;
    monthlyOperationalCost: string;
  };
  requiredEquipment: Array<{
    item: string;
    estimatedCost: string;
    searchKeyword: string;
  }>;
  locationStrategy: {
    bestLocations: string[];
    footTraffic: string;
    competition: string;
  };
  licenses: string[];
  revenuePotential: {
    dailySales: string;
    monthlySales: string;
  };
  digitalServices: Array<{
    service: string;
    estimatedCost: string;
  }>;
  youtubeVideo: string;
  businessThumbnail: string;
}
