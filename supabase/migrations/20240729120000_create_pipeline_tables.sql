-- Create the pipeline_stages table
CREATE TABLE
  pipeline_stages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    color TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

-- Create the pipeline_leads table
CREATE TABLE
  pipeline_leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE,
    client_id UUID REFERENCES clients (id) ON DELETE CASCADE,
    stage_id UUID REFERENCES pipeline_stages (id) ON DELETE CASCADE,
    estimated_value NUMERIC (10, 2),
    expected_close_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

-- Create policies for pipeline_stages
ALTER TABLE pipeline_stages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to manage their own stages" ON pipeline_stages FOR ALL USING (auth.uid () = user_id)
WITH
  CHECK (auth.uid () = user_id);

-- Create policies for pipeline_leads
ALTER TABLE pipeline_leads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to manage their own leads" ON pipeline_leads FOR ALL USING (auth.uid () = user_id)
WITH
  CHECK (auth.uid () = user_id); 