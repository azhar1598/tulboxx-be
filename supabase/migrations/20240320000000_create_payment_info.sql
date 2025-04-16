-- Create payment_info table
CREATE TABLE IF NOT EXISTS payment_info (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    account_holder_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    branch_code TEXT NOT NULL,
    routing_number TEXT NOT NULL,
    swift_code TEXT,
    tax_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS payment_info_user_id_idx ON payment_info(user_id);

-- Create RLS policies
ALTER TABLE payment_info ENABLE ROW LEVEL SECURITY;

-- Policy for selecting payment info (users can only see their own payment info)
CREATE POLICY "Users can view their own payment info"
    ON payment_info
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy for inserting payment info (users can only insert their own payment info)
CREATE POLICY "Users can insert their own payment info"
    ON payment_info
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy for updating payment info (users can only update their own payment info)
CREATE POLICY "Users can update their own payment info"
    ON payment_info
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy for deleting payment info (users can only delete their own payment info)
CREATE POLICY "Users can delete their own payment info"
    ON payment_info
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_payment_info_updated_at
    BEFORE UPDATE ON payment_info
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column(); 