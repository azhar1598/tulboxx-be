ALTER TABLE public.jobs
ADD COLUMN project_id UUID REFERENCES public.estimates(id) ON DELETE SET NULL;

