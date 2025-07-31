--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.13 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, company_name)
  VALUES (NEW.id, NULL);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

--
-- Name: handle_user_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_user_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.handle_user_update() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    email text,
    phone text,
    address text NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    city text NOT NULL,
    state text NOT NULL,
    zip text NOT NULL,
    notes text
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: search_clients_by_user(text, uuid, integer, integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, filter_id_arg uuid DEFAULT NULL::uuid) RETURNS SETOF public.clients
    LANGUAGE plpgsql
    AS $$
DECLARE
    offset_val INT;
BEGIN
    offset_val := (page_num - 1) * page_size;

    RETURN QUERY
    SELECT *
    FROM clients
    WHERE
        user_id = user_id_arg AND
        (filter_id_arg IS NULL OR id = filter_id_arg) AND
        (search_term IS NULL OR search_term = '' OR
            name ILIKE '%' || search_term || '%' OR
            email ILIKE '%' || search_term || '%' OR
            address ILIKE '%' || search_term || '%' OR
            city ILIKE '%' || search_term || '%' OR
            state ILIKE '%' || search_term || '%' OR
            notes ILIKE '%' || search_term || '%' OR
            CAST(phone AS TEXT) ILIKE '%' || search_term || '%' OR
            CAST(zip AS TEXT) ILIKE '%' || search_term || '%'
        )
    ORDER BY created_at DESC
    LIMIT CASE WHEN page_size = -1 THEN NULL ELSE page_size END
    OFFSET CASE WHEN page_size = -1 THEN 0 ELSE offset_val END;
END;
$$;


ALTER FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, filter_id_arg uuid) OWNER TO postgres;

--
-- Name: search_clients_by_user(text, uuid, integer, integer, text, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, sort_column text DEFAULT 'created_at'::text, sort_direction text DEFAULT 'DESC'::text, filter_id_arg uuid DEFAULT NULL::uuid) RETURNS SETOF public.clients
    LANGUAGE plpgsql
    AS $_$
DECLARE
    offset_val INT;
    valid_sort_direction TEXT;
    query_str TEXT;
BEGIN
    offset_val := (page_num - 1) * page_size;

    -- Validate sort_direction to be either ASC or DESC
    IF upper(sort_direction) = 'ASC' THEN
        valid_sort_direction := 'ASC';
    ELSE
        valid_sort_direction := 'DESC';
    END IF;

    -- NOTE: sort_column is validated in the application code to prevent SQL injection.
    query_str := format(
        'SELECT *
         FROM clients
         WHERE
             user_id = %1$L AND
             (%2$L IS NULL OR id = %2$L) AND
             (%3$L IS NULL OR %3$L = '''' OR
                 name ILIKE ''%%'' || %3$L || ''%%'' OR
                 email ILIKE ''%%'' || %3$L || ''%%'' OR
                 address ILIKE ''%%'' || %3$L || ''%%'' OR
                 city ILIKE ''%%'' || %3$L || ''%%'' OR
                 state ILIKE ''%%'' || %3$L || ''%%'' OR
                 notes ILIKE ''%%'' || %3$L || ''%%'' OR
                 CAST(phone AS TEXT) ILIKE ''%%'' || %3$L || ''%%'' OR
                 CAST(zip AS TEXT) ILIKE ''%%'' || %3$L || ''%%''
             )
         ORDER BY %4$I %5$s',
        user_id_arg,          -- 1
        filter_id_arg,        -- 2
        search_term,          -- 3
        sort_column,          -- 4
        valid_sort_direction  -- 5
    );

    IF page_size != -1 THEN
        query_str := query_str || format(' LIMIT %s OFFSET %s', page_size, offset_val);
    END IF;

    RETURN QUERY EXECUTE query_str;
END;
$_$;


ALTER FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, sort_column text, sort_direction text, filter_id_arg uuid) OWNER TO postgres;

--
-- Name: search_clients_by_user_count(text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_clients_by_user_count(search_term text, user_id_arg uuid, filter_id_arg uuid DEFAULT NULL::uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_records INT;
BEGIN
    SELECT COUNT(*)
    INTO total_records
    FROM clients
    WHERE
        user_id = user_id_arg AND
        (filter_id_arg IS NULL OR id = filter_id_arg) AND
        (search_term IS NULL OR search_term = '' OR
            name ILIKE '%' || search_term || '%' OR
            email ILIKE '%' || search_term || '%' OR
            address ILIKE '%' || search_term || '%' OR
            city ILIKE '%' || search_term || '%' OR
            state ILIKE '%' || search_term || '%' OR
            notes ILIKE '%' || search_term || '%' OR
            CAST(phone AS TEXT) ILIKE '%' || search_term || '%' OR
            CAST(zip AS TEXT) ILIKE '%' || search_term || '%'
        );
    RETURN total_records;
END;
$$;


ALTER FUNCTION public.search_clients_by_user_count(search_term text, user_id_arg uuid, filter_id_arg uuid) OWNER TO postgres;

--
-- Name: search_estimates(text, uuid, uuid, text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_estimates(search_term text, user_id_arg uuid, filter_id_arg uuid, sort_column text DEFAULT 'created_at'::text, sort_direction text DEFAULT 'DESC'::text, page_num integer DEFAULT 1, page_size integer DEFAULT 10) RETURNS TABLE(id uuid, user_id uuid, client_id uuid, "projectName" text, type text, "serviceType" text, "problemDescription" text, "solutionDescription" text, "projectEstimate" text, "projectStartDate" text, "projectEndDate" text, "lineItems" jsonb, "equipmentMaterials" text, "additionalNotes" text, ai_generated_estimate text, total_amount numeric, created_at timestamp with time zone, updated_at date, status text, clients json)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    offset_val INT;
    valid_sort_direction TEXT;
    query_str TEXT;
    search_pattern TEXT; -- Variable for the ILIKE pattern
BEGIN
    offset_val := (page_num - 1) * page_size;
    search_pattern := '%' || search_term || '%'; -- Build the pattern here

    IF upper(sort_direction) = 'ASC' THEN
        valid_sort_direction := 'ASC';
    ELSE
        valid_sort_direction := 'DESC';
    END IF;

    query_str := format('
      SELECT
        e.id, e.user_id, e.client_id, e."projectName", e.type, e."serviceType",
        e."problemDescription", e."solutionDescription", e."projectEstimate",
        e."projectStartDate", e."projectEndDate", e."lineItems", e."equipmentMaterials",
        e."additionalNotes", e.ai_generated_estimate, e.total_amount, e.created_at,
        e.updated_at, e.status,
        (SELECT row_to_json(c.*) FROM clients c WHERE c.id = e.client_id) AS clients
      FROM estimates AS e
      LEFT JOIN clients AS c ON e.client_id = c.id
      WHERE
          e.user_id = %1$L AND
          (%2$L IS NULL OR e.id = %2$L) AND
          (%3$L IS NULL OR %3$L = '''' OR
              e."projectName" ILIKE %4$L OR
              e.type ILIKE %4$L OR
              e."serviceType" ILIKE %4$L OR
              c.name ILIKE %4$L OR
              c.email ILIKE %4$L
          )
      ORDER BY %5$I %6$s',
      user_id_arg,          -- 1
      filter_id_arg,        -- 2
      search_term,          -- 3
      search_pattern,       -- 4
      sort_column,          -- 5
      valid_sort_direction  -- 6
    );

    IF page_size != -1 THEN
        query_str := query_str || format(' LIMIT %s OFFSET %s', page_size, offset_val);
    END IF;

    RETURN QUERY EXECUTE query_str;
END;
$_$;


ALTER FUNCTION public.search_estimates(search_term text, user_id_arg uuid, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) OWNER TO postgres;

--
-- Name: search_estimates_count(text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_estimates_count(search_term text, user_id_arg uuid, filter_id_arg uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_records INT;
BEGIN
    SELECT COUNT(*)
    INTO total_records
    FROM estimates AS e
    LEFT JOIN clients AS c ON e.client_id = c.id
    WHERE
        e.user_id = user_id_arg AND
        (filter_id_arg IS NULL OR e.id = filter_id_arg) AND
        (search_term IS NULL OR search_term = '' OR
            e."projectName" ILIKE '%' || search_term || '%' OR
            e.type ILIKE '%' || search_term || '%' OR
            e."serviceType" ILIKE '%' || search_term || '%' OR
            c.name ILIKE '%' || search_term || '%' OR
            c.email ILIKE '%' || search_term || '%'
        );
    RETURN total_records;
END;
$$;


ALTER FUNCTION public.search_estimates_count(search_term text, user_id_arg uuid, filter_id_arg uuid) OWNER TO postgres;

--
-- Name: search_invoices(text, text, uuid, text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_invoices(search_term text, user_id_arg text, filter_id_arg uuid, sort_column text DEFAULT 'created_at'::text, sort_direction text DEFAULT 'DESC'::text, page_num integer DEFAULT 1, page_size integer DEFAULT 10) RETURNS TABLE(id uuid, user_id text, client_id uuid, project_id uuid, invoice_number character varying, issue_date timestamp with time zone, due_date timestamp with time zone, invoice_total_amount numeric, line_items jsonb, invoice_summary text, remit_payment jsonb, additional_notes text, created_at timestamp with time zone, updated_at timestamp with time zone, status character varying, estimate_id uuid, client json, project json)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    offset_val INT;
    valid_sort_direction TEXT;
    query_str TEXT;
    search_pattern TEXT;
BEGIN
    offset_val := (page_num - 1) * page_size;
    search_pattern := '%' || search_term || '%';

    IF upper(sort_direction) = 'ASC' THEN
        valid_sort_direction := 'ASC';
    ELSE
        valid_sort_direction := 'DESC';
    END IF;

    query_str := format('
      SELECT
        i.id, i.user_id, i.client_id, i.project_id, i.invoice_number, i.issue_date,
        i.due_date, i.invoice_total_amount, i.line_items, i.invoice_summary,
        i.remit_payment, i.additional_notes, i.created_at, i.updated_at, i.status,
        i.estimate_id,
        (SELECT row_to_json(c.*) FROM clients c WHERE c.id = i.client_id) AS client,
        (SELECT row_to_json(p.*) FROM estimates p WHERE p.id = i.project_id) AS project
      FROM invoices AS i
      LEFT JOIN clients AS c ON i.client_id = c.id
      LEFT JOIN estimates AS p ON i.project_id = p.id
      WHERE
          i.user_id = %1$L AND
          (%2$L IS NULL OR i.id = %2$L) AND
          (%3$L IS NULL OR %3$L = '''' OR
              i.invoice_number ILIKE %4$L OR
              i.status ILIKE %4$L OR
              c.name ILIKE %4$L OR
              c.email ILIKE %4$L OR
              p."projectName" ILIKE %4$L
          )
      ORDER BY %5$I %6$s',
      user_id_arg,
      filter_id_arg,
      search_term,
      search_pattern,
      sort_column,
      valid_sort_direction
    );

    IF page_size != -1 THEN
        query_str := query_str || format(' LIMIT %s OFFSET %s', page_size, offset_val);
    END IF;

    RETURN QUERY EXECUTE query_str;
END;
$_$;


ALTER FUNCTION public.search_invoices(search_term text, user_id_arg text, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) OWNER TO postgres;

--
-- Name: search_invoices_count(text, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_invoices_count(search_term text, user_id_arg text, filter_id_arg uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_records INT;
BEGIN
    SELECT COUNT(*)
    INTO total_records
    FROM invoices AS i
    LEFT JOIN clients AS c ON i.client_id = c.id
    LEFT JOIN estimates AS p ON i.project_id = p.id
    WHERE
        i.user_id = user_id_arg AND
        (filter_id_arg IS NULL OR i.id = filter_id_arg) AND
        (search_term IS NULL OR search_term = '' OR
            i.invoice_number ILIKE '%' || search_term || '%' OR
            i.status ILIKE '%' || search_term || '%' OR
            c.name ILIKE '%' || search_term || '%' OR
            c.email ILIKE '%' || search_term || '%' OR
            p."projectName" ILIKE '%' || search_term || '%'
        );
    RETURN total_records;
END;
$$;


ALTER FUNCTION public.search_invoices_count(search_term text, user_id_arg text, filter_id_arg uuid) OWNER TO postgres;

--
-- Name: sync_auth_to_public_users(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sync_auth_to_public_users() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO public.users (id, email, created_at)
    VALUES (NEW.id, NEW.email, NOW())
    ON CONFLICT (id) DO NOTHING; -- Prevent duplicate inserts
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.sync_auth_to_public_users() OWNER TO postgres;

--
-- Name: update_modified_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_modified_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_modified_column() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: contents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contents (
    id bigint NOT NULL,
    project_id uuid,
    post_type character varying NOT NULL,
    advice text,
    benefit text,
    platform character varying NOT NULL,
    tone character varying NOT NULL,
    length character varying NOT NULL,
    use_emojis boolean DEFAULT false,
    use_hashtags boolean DEFAULT false,
    status character varying DEFAULT 'draft'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    content text,
    user_id uuid NOT NULL
);


ALTER TABLE public.contents OWNER TO postgres;

--
-- Name: contents_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.contents ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estimates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estimates (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    "projectName" text NOT NULL,
    "serviceType" text,
    "problemDescription" text,
    "solutionDescription" text,
    "projectEstimate" text,
    "projectStartDate" text,
    "projectEndDate" text,
    "lineItems" jsonb,
    "equipmentMaterials" text,
    "additionalNotes" text,
    total_amount numeric,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'pending'::text,
    ai_generated_estimate text,
    user_id uuid NOT NULL,
    client_id uuid,
    updated_at date,
    type text
);


ALTER TABLE public.estimates OWNER TO postgres;

--
-- Name: invoices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_number character varying(10) NOT NULL,
    issue_date timestamp with time zone NOT NULL,
    due_date timestamp with time zone,
    invoice_total_amount numeric(12,2) NOT NULL,
    line_items jsonb NOT NULL,
    invoice_summary text NOT NULL,
    remit_payment jsonb NOT NULL,
    estimate_id uuid,
    additional_notes text,
    status character varying(20) DEFAULT 'unpaid'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    project_id uuid,
    user_id text,
    client_id uuid,
    CONSTRAINT status_check CHECK (((status)::text = ANY ((ARRAY['unpaid'::character varying, 'paid'::character varying, 'overdue'::character varying, 'cancelled'::character varying, 'draft'::character varying])::text[])))
);


ALTER TABLE public.invoices OWNER TO postgres;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid,
    name character varying NOT NULL,
    type character varying,
    description text,
    date timestamp with time zone,
    amount numeric,
    hours numeric,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone
);


ALTER TABLE public.jobs OWNER TO postgres;

--
-- Name: payment_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payment_info (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    account_holder_name text NOT NULL,
    account_number text NOT NULL,
    bank_name text NOT NULL,
    branch_code text NOT NULL,
    routing_number text NOT NULL,
    swift_code text,
    tax_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.payment_info OWNER TO postgres;

--
-- Name: pipeline_leads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pipeline_leads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    client_id uuid,
    stage_id uuid,
    estimated_value numeric(10,2),
    expected_close_date date,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pipeline_leads OWNER TO postgres;

--
-- Name: pipeline_stages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pipeline_stages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    name text NOT NULL,
    description text,
    color text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.pipeline_stages OWNER TO postgres;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    company_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    job_title text,
    industry text,
    plan text,
    company_size text,
    address text
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: user_profiles; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_profiles AS
 SELECT p.id,
    p.company_name,
    p.company_size,
    p.address,
    p.plan,
    p.industry,
    p.job_title,
    u.email,
    (u.email_confirmed_at IS NOT NULL) AS email_confirmed,
    u.raw_user_meta_data
   FROM (public.profiles p
     JOIN auth.users u ON ((p.id = u.id)));


ALTER TABLE public.user_profiles OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    first_name text,
    last_name text,
    created_at timestamp without time zone DEFAULT now(),
    email text NOT NULL,
    full_name text NOT NULL,
    phone text NOT NULL,
    address text NOT NULL,
    company_name text,
    job_title text,
    industry text,
    company_size text,
    email_notifications boolean DEFAULT true,
    sms_notifications boolean DEFAULT false,
    role text DEFAULT 'user'::text,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.users IS 'User profiles with extended information';


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id, name, email, phone, address, user_id, created_at, updated_at, city, state, zip, notes) FROM stdin;
e056cef7-d455-4f49-a63d-d446218db39b	Azhar Mohammed	neon.1598@gmail.com	816356485	Astalaxmi Nilayam, Flat No.G1, Kaviraj Nagar Street No.6	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-07-13 09:40:59.313+00	2025-07-13 10:08:23.529+00	Birmingham	Alabama	507002	king
54d3809e-869d-4bef-b6ab-3703d6a84897	Azhar Mohammed	mohammedazhar.1598@gmail.com	91822897546	Astalaxmi Nilayam, Flat No.G1, Kaviraj Nagar Street No.6	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-13 09:10:15.678+00	2025-07-30 07:41:04.82+00	Mesa	Arizona	70923	
ef9ef555-351a-4c0c-b2b4-3c4e69f1a926	rajesh	\N	\N		50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-07-30 07:41:31.232+00	\N				
46c58c60-8e9b-4d10-a525-eb5788bbe00f	azhar	\N	22		50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-07-30 07:20:13.275+00	2025-07-30 12:11:58.49+00			213423	wf
156a5db3-4c0d-4716-99f2-5ad8bff6bf65	Azhar Mohammed	har.1598@gmail.com	81736483645	Astalaxmi Nilayam, Flat No.G1, Kaviraj Nagar Street No.6	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-07-13 12:02:02.419+00	\N	Mobile	Alabama	507002	
e63f515e-2515-4c76-b79a-b639b35e1327	Azhar Mohammed	mohammesdazhar.1598@gmail.com	9182289774	Astalaxmi Nilayam, Flat No.G1, Kaviraj Nagar Street No.6	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-13 09:35:27.358+00	2025-04-13 09:35:35.676+00	N/A	N/A	N/A	\N
67e56aaa-0e04-4d61-8834-61e4c80f3f99	Tillu	mohaemmedazhar@gmail.com	893745634	H.NO:7-3-32,DWARKA NAGAR,GATTIAH CENTER.	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-13 11:37:01.795+00	\N	N/A	N/A	N/A	\N
306a3b82-d6e7-4d95-92a7-3975d54c7c18	Rajesh	rajesh@mail.com	89374627423	H.NO:7-3-32,DWARKA NAGAR,GATTIAH CENTER.	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-13 11:38:29.94+00	\N	N/A	N/A	N/A	\N
1e378ac4-f794-4c8b-ad5d-a4f5fb601b8f	Mohammed Azhar	mohammedazhar.9645@gmail.com	91822823771	Vdos Colonies	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-15 18:06:28.984+00	2025-04-15 18:07:09.06+00	N/A	N/A	N/A	\N
d102be73-f74a-45db-9d24-38e2a603246b	tharn	tharun@mail.com	8977832678	Astalaxmi Nilayam, Flat No.G1, Kaviraj Nagar Street No.6	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-15 18:08:09.813+00	\N	N/A	N/A	N/A	\N
22bddeea-4f72-442d-a7fb-ec49e2e18c0e	salman	salman@mail.com	8977836453	Vdos Colon	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-13 12:48:11.228+00	2025-04-16 19:11:25.8+00	N/A	N/A	N/A	\N
10ae84c7-2da6-4f99-950d-5a18dd5ed203	Mohammed Azhar	mohammedazharaa1598@gmail.com	897782625347	Vdos Colony	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-17 10:34:44.54+00	\N	N/A	N/A	N/A	\N
df0c7d05-c664-41ca-a371-7a4645c7657a	Mohammed Azhar	azhar.1598@gmail.com	9182289771	Vdos Colonies	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-13 09:36:01.796+00	2025-04-17 10:43:09.21+00	N/A	N/A	N/A	\N
8c42f67e-ccc1-4465-8912-55b4e7f86254	sumanth	sumannth@mail.com	8923736548	harare	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-17 16:12:29.825+00	\N	N/A	N/A	N/A	\N
b8b8032f-5b5e-4e63-a823-2d77afea7806	prem	premkumar@mail.com	8977835626	Astlalaxmi Nilayam	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:37:07.368+00	\N	N/A	N/A	N/A	\N
54dd4914-32da-40be-86bf-0f2d7268666f	codecom	codecommunity01@gmail.com	8977836251	Ramya Ground Rd, beside Mad Over Maggi, near Vinayaka Temple, 3rd Phase, Kukatpally Housing Board Colony, Kukatpally	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:39:08.656+00	\N	N/A	N/A	N/A	\N
95598f83-8a4d-4ac0-8be0-8059c7ea22ea	verma	simplafacts011@gmail.com	89778367234	H.NO:7-3-32,DWARKA NAGAR,GATTIAH CENTER.	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:46:54.026+00	\N	N/A	N/A	N/A	\N
098becc7-01fd-403d-8bc8-7d24fc7bbc32	ewvewv	asf@mail.com	2987364	j	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:48:51.009+00	\N	N/A	N/A	N/A	\N
8c6e7da3-568b-4495-ad82-6bdc19e69d78	mfk	mbf@mail.com	3424	ekfe	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:52:09.373+00	\N	N/A	N/A	N/A	\N
af7ea608-6ab7-4eb5-a377-e191eee7c8f0	santra	sajr@gmail.com	893735276	jbreb	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:52:28.449+00	\N	N/A	N/A	N/A	\N
5b22b081-be27-4595-a480-d0c051770eec	han	hui@mail.com	9274773	sjr	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:53:54.865+00	\N	N/A	N/A	N/A	\N
432ce444-aad8-42e6-a294-fae905bb82f4	orli	orli@mail.com	839478347	orli olive	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 10:54:30.569+00	\N	N/A	N/A	N/A	\N
3885ad81-12b4-48e2-8d7b-829a8184480f	bilal	danger1903@mail.com	8927362846	karan nagar	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 11:09:48.301+00	\N	N/A	N/A	N/A	\N
5e491541-f3cf-4730-a555-e1a9b3fe075a	poorna	poorna@mail.com	897733562	jay nagar	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 11:13:58.08+00	\N	N/A	N/A	N/A	\N
af5e7c0c-168f-4f81-a084-ea7c94a5f142	jan	uary@mail.com	89726452643	bgm	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:02:28.692+00	\N	N/A	N/A	N/A	\N
cd0ece34-b6ff-4f55-b4d7-f9662f812a3c	sky	skyrocket@mail.com	7829763567	sky	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:06:29.522+00	\N	N/A	N/A	N/A	\N
150b6138-0a0d-4d3e-bc5a-da191f36f322	tun	tuntun@mail.com	7892937468	dhlak pur	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:12:23.656+00	\N	N/A	N/A	N/A	\N
0dbe530d-55e9-43df-95b7-aeaa43cde136	sam	samosa@mail.com	8926738493	sam sundar colony	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:12:53.021+00	\N	N/A	N/A	N/A	\N
d38f47ad-e1cc-40c6-95c8-e1e331aa4e6f	tami	tami@mail.com	8927363846	tami area	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:16:06.583+00	\N	N/A	N/A	N/A	\N
fc08d199-1850-4215-8c81-e4ccbb7575f3	brazki	braxki@mail.com	937837478	braxki arke	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:16:40.603+00	\N	N/A	N/A	N/A	\N
bdf5af98-b0a7-48a8-b1f7-490eb46cb143	jab	jav@mail.com	836485683736	Jab area	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:18:12.271+00	\N	N/A	N/A	N/A	\N
ce7a95be-2df0-4f21-8ba5-ab9958b8d5c7	badeb	bade@mail.com	89772363413	bade area	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:29:55.69+00	\N	N/A	N/A	N/A	\N
75650f36-4edf-47ba-96d3-9234ae2bbe67	nani	nai@mail.com	89274649375	nani area	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:32:25.423+00	\N	N/A	N/A	N/A	\N
0cfea557-825d-4dc7-b19c-401c5addab8b	wio	wio@mail.com	892736483647	wio area	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:33:20.886+00	\N	N/A	N/A	N/A	\N
c23efca5-e794-404f-8c32-9c62c7b82e23	nal	mal@mail.vom	8297464836	msior	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 12:37:42.226+00	\N	N/A	N/A	N/A	\N
1164e82b-b2c2-4a15-9863-af2f0a001f6e	Mohammed Azhar	mohammedazhar.159998@gmail.com	897765454445	Vdos Colony	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 15:01:42.095+00	\N	N/A	N/A	N/A	\N
651956eb-22ed-41ed-95ce-2fafdcab50f0	Mohammed Azhar	mohammedazhar.15948@gmail.com	783747263433	Vdos Colony	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 15:58:55.123+00	\N	N/A	N/A	N/A	\N
1a3c96b2-5920-4dce-8543-f40ce3e32cf1	newworld	newera@mail.com	8143631527	diljeet area	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 16:07:45.208+00	2025-04-18 16:08:09.797+00	N/A	N/A	N/A	\N
321eb93c-346a-4777-9cc2-274fdf6df383	samsungg	sanjusamson@mail.com	8977835263	era code area, KMM,TG	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 16:09:51.989+00	2025-04-18 16:10:58.49+00	N/A	N/A	N/A	\N
68d2d543-f52a-4130-a457-5471bf8a2856	byju	byju@mail.com	89778363526	byju address	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 16:16:03.511+00	\N	N/A	N/A	N/A	\N
554217bb-a320-4b76-b4b1-df4e54012176	jared & Ashley hood 	Ashley.domer@gmail.com	8324743312	140 quiet springs trail Willis Texas 	d194c33a-5679-4dcb-b22c-fac98cfec3cf	2025-06-17 12:01:51.008+00	\N	N/A	N/A	N/A	\N
c9a6d5ce-d4a3-4e2c-b1bf-750f1c1995b5	Mohammed Azhar	mohammedazhar.245@gmail.com	81735637813	ratnagiri takis	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 16:44:29.896+00	2025-04-18 16:44:47.165+00	N/A	N/A	N/A	\N
19520e84-fe1a-4742-8bf1-0586bcf6f0c0	zaki	zaki@gmail.com	81436143022	Peoria,illinois, USA	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 18:04:38.923+00	\N	N/A	N/A	N/A	\N
839b6b01-af69-4d9c-baab-efebe14e67db	zakiuddin	zakiuddin@gmail.com	8143627363	H.NO:7-3-32,DWARKA NAGAR,GATTIAH CENTER.	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-18 18:07:16.263+00	\N	N/A	N/A	N/A	\N
8d7d81a4-0b07-4493-a840-acf0e56f4c4b	samosa	samosaman@gmail.com	8977382527	colony era	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-04-19 14:39:40.464+00	\N	N/A	N/A	N/A	\N
e0abaf61-3f57-4009-b168-b07db5e48d74	Tharun	Tharunkumarpanga@gmail.com	3099898037	Peoria, illinois	d9432cc7-89b9-45ab-9ffc-365a86939107	2025-04-19 15:06:25.596+00	2025-04-19 15:08:19.699+00	N/A	N/A	N/A	\N
6f9d9ba9-3755-434f-9dcf-d960e3253c62	David	David@gmail.com	3099898039	Peoria, Illinois	d9432cc7-89b9-45ab-9ffc-365a86939107	2025-04-19 15:10:07.184+00	2025-04-19 15:10:32.294+00	N/A	N/A	N/A	\N
5f894019-d57e-47dc-aa3e-3bd0464e9ef1	Robert Dobrilovic	robert@robertgoodwill.com	385921330182	Manterovcak 18	94ef9a8f-98e7-46ca-ad16-a9bbceef6ca6	2025-04-22 09:35:44.35+00	\N	N/A	N/A	N/A	\N
3afba4f2-cd52-47f1-b9e6-c05130557a07	Nemo imao	client@gmail.com	555555555	Liberty street nn.	4a131143-f973-4f8d-8b4b-83fafedcf9df	2025-04-23 13:11:16.567+00	\N	N/A	N/A	N/A	\N
44652c5e-c833-422c-bcc1-1b848646d2f6	Ryan Deemer	deemer63@gmail.com	3093695865	11222 N Tuscany Ridge Ct.	835c094d-bb0a-4ccc-97b0-228210ea817b	2025-05-13 18:27:04.732+00	\N	N/A	N/A	N/A	\N
f08bbbc3-f8b5-4aa3-ba4b-66157799fd49	sumanth	sumanth@gmail.com	8927472384	VDOS area	961af7eb-1a61-47ac-9fd4-e8174218a32f	2025-05-13 19:18:01.706+00	\N	N/A	N/A	N/A	\N
1a00e395-fb2d-48f3-a7f5-46754937796e	Dan Morgan	dan@123.com	3095555555	123 mian st\nPeoria Il 61515	835c094d-bb0a-4ccc-97b0-228210ea817b	2025-05-22 16:04:28.637+00	\N	N/A	N/A	N/A	\N
4c1b10bb-e53f-4ff8-8127-8aeda4d7982d	Bob Jones	bob@gmail.com	5555555555	123 N Main	71fbf873-af4f-4f51-95f1-153ba64776e3	2025-05-30 12:19:01.153+00	\N	N/A	N/A	N/A	\N
1047650c-dc8a-4506-b3ea-c945e007b2e9	BJ Gingerich 	None@none.com	3092088882	26770 Allentown Rd Tremont IL 61568	7db369b9-1144-4395-931d-abf2b3b4a4ea	2025-06-01 22:54:37.356+00	\N	N/A	N/A	N/A	\N
ce5d7952-77f7-4578-8c4a-4c94c669dd2b	Tanner McMurray 	Tanner.TTLroofing@gmail.com	9363141108	10815 sailview street\nMontgomery texas 77356	d194c33a-5679-4dcb-b22c-fac98cfec3cf	2025-06-12 17:30:06.44+00	\N	N/A	N/A	N/A	\N
4435a254-a5aa-4bb7-8bb6-cc158da48bbe	Wingo service company inc 	ewingo@wingocompianes.com	2813579990	11173 cox road Conroe Texas 	d194c33a-5679-4dcb-b22c-fac98cfec3cf	2025-06-21 12:27:55.758+00	\N	N/A	N/A	N/A	\N
4f95ebf0-8d36-4bb6-8013-50364223b382	Wes Sperry	mrbssmn@gmail.com	3098631221	415 N Main St Washington, IL 61571	7db369b9-1144-4395-931d-abf2b3b4a4ea	2025-06-21 20:31:02.323+00	\N	N/A	N/A	N/A	\N
e793b017-12e4-4d7a-a9fc-30b57e84ff01	Tyler Swanson	tyler.swanson85@gmail.com	3092647549	713 Agnes Dr Washington, IL 61571	7db369b9-1144-4395-931d-abf2b3b4a4ea	2025-06-21 20:35:55.901+00	\N	N/A	N/A	N/A	\N
bb56f831-4c93-47f1-843b-d82e4104fc8f	Steve Dudley	none@none.com	3094720600	5 Hillcrest Ct	7db369b9-1144-4395-931d-abf2b3b4a4ea	2025-06-21 20:43:26.241+00	\N	N/A	N/A	N/A	\N
09f84dfa-884a-4050-8235-01ac5bf87ac5	Steve Stewart	none1@none.com	3098402828	118 Glen Dr Eureka, IL 	7db369b9-1144-4395-931d-abf2b3b4a4ea	2025-06-22 19:54:08.241+00	\N	N/A	N/A	N/A	\N
3612ec74-1141-4ceb-9a36-de675560fddd	Rich Lampshire 	lampsboards@yahoo.com	7203140963	60 quiet springs trail Willis Texas 77378	d194c33a-5679-4dcb-b22c-fac98cfec3cf	2025-06-27 14:52:41.532+00	\N	N/A	N/A	N/A	\N
a2d48cbc-d085-4137-9ac9-0e2096186f62	Tyler Conner	tconner1052@gmail.com	7207933823	11151 Williams Reserve Dr conroe Texas 77303	d194c33a-5679-4dcb-b22c-fac98cfec3cf	2025-07-01 21:54:10.533+00	\N	N/A	N/A	N/A	\N
e05439e8-1d83-4a4e-910b-33376625a2b1	George Thornton	bluusmoke@gmail.com	9366725718	 quite springs trail	d194c33a-5679-4dcb-b22c-fac98cfec3cf	2025-06-19 12:22:16.16+00	2025-07-01 22:17:42.215+00	N/A	N/A	N/A	\N
966b3b83-0c51-4147-b2a5-4d8774d206e0	Julia Cruz 	juliacruz95@yahoo.com	936555555	13721 Creighton road Conroe Texas 77301	d194c33a-5679-4dcb-b22c-fac98cfec3cf	2025-07-04 21:38:45.247+00	\N	N/A	N/A	N/A	\N
6c62f62b-e8ba-4deb-ac81-0dabae3a2cb2	Aaron Gruber	none2@none.com	3096488844	115 Aspen Ct East Peoria, IL 61611	7db369b9-1144-4395-931d-abf2b3b4a4ea	2025-07-05 15:16:12.774+00	\N	N/A	N/A	N/A	\N
b4be0b4a-4be0-4d9e-a8ae-116442248336	Ryan Blackorby	none3@none.com	3096576787	104 E Jefferson St, Washington, IL 61571	7db369b9-1144-4395-931d-abf2b3b4a4ea	2025-07-10 02:47:56.058+00	\N	N/A	N/A	N/A	\N
30a2a1c1-4c7d-4854-812b-186659d6087c	david	david@gmail.com	918273645347	123 main st	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-07-14 18:11:50.175+00	\N	Peoria	Illinois	16062	Nothing
309da15a-0a98-49bb-b02d-1ccb3ac323bb	tarun	\N	\N		50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	2025-07-30 07:41:24.104+00	\N				
\.


--
-- Data for Name: contents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contents (id, project_id, post_type, advice, benefit, platform, tone, length, use_emojis, use_hashtags, status, created_at, updated_at, content, user_id) FROM stdin;
7	c517aa79-8476-4b7b-970c-10acc1468126	Tips & Advice	Ways to prepare your yard for winter	Helps prevent plant damage and ensure your yard is ready is ready for spring	Instagram	Professional	Medium	t	f	draft	2025-04-01 14:24:32.996+00	\N	```json\n{\n  "content": "Winter is coming! ❄️ Preparing your yard now can save you headaches (and money!) in the spring. Here are a few tips:\\n\\n🍂 Rake and remove fallen leaves to prevent mold and disease.\\n🌳 Prune dead or damaged branches to avoid breakage under heavy snow.\\n💧 Disconnect and drain outdoor hoses to prevent freezing and bursting.\\n🌱 Add a layer of mulch around sensitive plants for insulation.\\n\\nTaking these simple steps now helps protect your plants from winter damage and ensures a healthier, more vibrant yard when spring arrives. 🌷",\n  "title": "Get Your Yard Ready for Winter!",\n  "visual_content_idea": "A photo or short video demonstrating one of the winterizing tips, such as mulching plants or disconnecting a hose."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
8	c517aa79-8476-4b7b-970c-10acc1468126	Tips & Advice	ways to prepare your yard for winter	helps prevent plant damage and ensures your yard is ready for spring	Instagram	Friendly	Medium	t	f	draft	2025-04-01 14:35:36.676+00	\N	```json\n{\n  "content": "Winter is coming! ❄️ Get your yard ready now to avoid damage and ensure a beautiful spring bloom! Here are a few quick tips:\\n\\n🍂 Rake up those leaves! Piles of wet leaves can smother your grass.\\n\\n🌳 Prune your trees and shrubs. Remove any dead or damaged branches before winter storms hit.\\n\\n💧 Disconnect your hoses and drain your outdoor faucets to prevent freezing and bursting pipes. No one wants that!\\n\\n🌱 Add a layer of mulch around sensitive plants for extra insulation. \\n\\nDoing these simple things now will save you time and effort in the spring, and help your plants thrive! Happy prepping! 😊",\n  "title": "Winter Yard Prep Tips!",\n  "visual_content_idea": "A carousel post. Image 1: Before & After of raking leaves. Image 2: Close up of pruning shears with a shrub. Image 3: Disconnecting a hose from an outdoor faucet. Image 4: Applying mulch around a plant."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
9	64dbcba2-2430-4e08-8527-c68c96b295a8	Promotion	Ways to prepare your yard for winter	Helps prevent damage in winter	Instagram	Friendly	Medium	t	t	draft	2025-04-01 18:22:43.745+00	\N	```json\n{\n  "content": "Winter is coming! ❄️ Is your yard ready? 🍂 Preparing your outdoor space now can save you headaches (and money!) later. Here are a few simple tips:\\n\\n*   **Clean up those leaves!** 🍁 Raking prevents mold and protects your lawn.\\n*   **Prune your trees and shrubs.** 🌳 Remove dead or broken branches to prevent damage from snow and ice.\\n*   **Protect your pipes.** 💧 Insulate exposed pipes to avoid freezing and bursting.\\n*   **Aerate your lawn.** 🌬️ This helps water drain and prevents compaction.\\n\\nTaking these steps now will help prevent costly damage and ensure your yard is healthy and ready to thrive come springtime! 🌷 #WinterPrep #YardCare #FallMaintenance #HomeImprovement #WinterIsComing #Landscaping #DIY #Garden",\n  "title": "Get Your Yard Winter-Ready!",\n  "visual_content_idea": "A carousel post. The first image could be a beautiful fall yard. Subsequent images would show close-ups of the tips mentioned (raking leaves, pruning, insulating pipes, aerating), with text overlays highlighting each tip. The last image could be a snowy yard with a caption reminding people that taking preparatory steps now will lead to a healthier yard in the spring."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
10	c517aa79-8476-4b7b-970c-10acc1468126	Tips & Advice	ways to prepare your yard for summer	Helps prevent plant damage	LinkedIn	Professional	Long	t	t	draft	2025-04-05 20:03:16.82+00	\N	```json\n{\n  "content": "Summer is almost here! ☀️ Prepare your yard now to protect your plants from the harsh conditions ahead. Here are some tips to help prevent plant damage and keep your garden thriving:\\n\\n1️⃣ **Deep Watering:** Water deeply and less frequently to encourage strong root growth. Aim for early morning watering to minimize evaporation.\\n\\n2️⃣ **Mulch, Mulch, Mulch:** Apply a thick layer of mulch around your plants. This helps retain moisture, regulate soil temperature, and suppress weeds. Choose organic options like wood chips or shredded bark.\\n\\n3️⃣ **Prune Strategically:** Remove any dead, damaged, or diseased branches. This improves air circulation and reduces the risk of pests and diseases. Proper pruning encourages healthy growth and blooming.\\n\\n4️⃣ **Fertilize Wisely:** Use a slow-release fertilizer to provide essential nutrients throughout the summer. Avoid over-fertilizing, as this can stress plants during hot weather.\\n\\n5️⃣ **Pest and Disease Control:** Regularly inspect your plants for signs of pests or diseases. Address issues promptly with appropriate treatments. Consider using organic pest control methods whenever possible.\\n\\n6️⃣ **Provide Shade:** If you have plants that are sensitive to direct sunlight, consider providing some shade during the hottest part of the day. Use shade cloths, umbrellas, or plant taller plants nearby.\\n\\n7️⃣ **Weed Control:** Regularly remove weeds to prevent them from competing with your plants for water and nutrients. Hand-pulling or hoeing are effective methods.\\n\\nBy taking these steps now, you can protect your plants from the stresses of summer and enjoy a beautiful, healthy garden all season long! 🌷🌿\\n\\n#SummerGardening #YardCare #PlantCare #GardeningTips #SummerPrep #LawnCare #PlantProtection #SustainableGardening #LinkedInGardening #GardenMaintenance",\n  "title": "Prepare Your Yard for Summer: Protect Your Plants and Prevent Damage",\n  "visual_content_idea": "A carousel post featuring images of different yard care tips, such as mulching, watering, pruning, and pest control. Each image should be accompanied by a short caption highlighting the benefits of each tip."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
11	d670a38f-a21b-4757-85f6-e2c6b6c58780	Tips & Advice	Ways to prevent yard from winter	helps prevent plant damage and ensures your yard is ready for spring	Instagram	Professional	Medium	t	f	draft	2025-04-06 15:57:02.289+00	\N	```json\n{\n  "content": "Winterizing your yard is crucial for its health! ❄️ Here are a few tips to prepare your outdoor space for the colder months:\\n\\n✅ **Clean up debris:** Remove fallen leaves and dead branches to prevent mold and pests.\\n✅ **Protect vulnerable plants:** Wrap shrubs with burlap or use mulch to insulate roots.\\n✅ **Aerate your lawn:** This helps nutrients reach the roots before the ground freezes.\\n✅ **Drain your sprinkler system:** Prevent burst pipes by draining and insulating your irrigation system.\\n\\nBy taking these steps now, you'll prevent plant damage and ensure your yard is ready to thrive in the spring! 🌷🌿",\n  "title": "Winterize Your Yard: Preparing for the Cold",\n  "visual_content_idea": "A carousel post. The first image is a picturesque fall yard. The second image is of someone raking leaves. The third image is of a shrub wrapped in burlap. The fourth image is of a sprinkler system being drained."\n}\n```	961af7eb-1a61-47ac-9fd4-e8174218a32f
12	\N	Tips & Advice	prepare for winter	prevent plant damage	Instagram	Professional	Short	t	f	draft	2025-04-17 11:45:42.926+00	\N	```json\n{\n  "content": "Winter is coming! ❄️ Protect your plants from the cold. Insulate, move indoors, or add mulch to prevent damage and ensure they thrive next spring. 🌱",\n  "title": "Winter Plant Prep",\n  "visual_content_idea": "A split-screen image showing a healthy plant in summer and a plant being protected with mulch/covering for winter."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
13	\N	Tips & Advice	ways to prepare for your yard	prevent plant damage	Facebook	Professional	Medium	t	f	draft	2025-04-18 13:22:31.457+00	\N	```json\n{\n  "content": "Getting your yard ready for the changing seasons is crucial for the health of your plants! Here are a few tips to help prevent plant damage: \\n\\n✅ **Assess your plants:** Check for any signs of disease, pests, or damage. Address these issues promptly to prevent them from spreading.\\n\\n🍂 **Clear Debris:** Remove fallen leaves, branches, and other debris that can harbor pests and diseases.\\n\\n💧 **Adjust Watering:** As temperatures change, adjust your watering schedule accordingly. Overwatering can be just as harmful as underwatering.\\n\\n🛡️ **Protect Sensitive Plants:** Cover or move sensitive plants indoors if frost is expected. Consider using mulch to insulate roots.\\n\\nBy taking these simple steps, you can help your plants thrive and enjoy a beautiful yard all season long!",\n  "title": "Prep Your Yard for Success!",\n  "visual_content_idea": "Image or short video demonstrating one of the yard preparation tips, such as clearing debris or covering plants."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
14	a0ef366b-dec9-45d2-aa5d-617f95ffe12c	Tips & Advice	ways to prepare your yard for winter	helps prevent plant damage and ensures your yard is ready for spring	Facebook	Engaging	Long	t	t	draft	2025-04-18 16:39:50.725+00	\N	```json\n{\n  "content": "Winter is coming! ❄️ Is your yard ready? Preparing your outdoor space now can save you a lot of headaches (and heartache!) when spring rolls around. Here are some key tips to get your yard winter-ready:\\n\\n🍂 **Clean Up Debris:** Rake up fallen leaves 🍁 and remove dead plants. This prevents mold and pests from overwintering in your garden. Don't forget to clear gutters too!\\n\\n🌳 **Prune Trees and Shrubs:** Trim dead or damaged branches to prevent them from breaking under the weight of snow and ice. Consult with a local expert for specific pruning guidelines for your plant types.\\n\\n🌷 **Protect Tender Plants:** Cover sensitive plants with burlap, blankets, or mulch to insulate them from freezing temperatures. Consider bringing potted plants indoors.\\n\\n💧 **Winterize Irrigation Systems:** Drain your sprinkler system completely to prevent pipes from freezing and bursting. Insulate exposed pipes.\\n\\n🌱 **Mulch, Mulch, Mulch!:** Add a thick layer of mulch around the base of your plants to protect their roots from the cold and retain moisture. This is especially important for newly planted trees and shrubs.\\n\\n🌿 **Consider a Winter Cover Crop:** Planting a cover crop like rye or clover can help prevent soil erosion and add nutrients back into the soil over the winter.\\n\\nBy taking these steps now, you'll be giving your plants the best chance to survive the winter and thrive in the spring! 🌸 A little preparation goes a long way towards a healthy and beautiful yard next year. Happy gardening! 👩‍🌾\\n\\n#WinterPrep #YardCare #GardeningTips #WinterGardening #FallCleanup #PrepareForWinter #HealthyPlants #SpringReady #GardenMaintenance #Landscaping",\n  "title": "Get Your Yard Winter-Ready! ❄️ Protect Your Plants and Prepare for Spring!",\n  "visual_content_idea": "A collage of photos showing each winter preparation step: raking leaves, pruning branches, covering plants, and mulching. Alternatively, a short video demonstrating each tip."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
15	\N	Tips & Advice	ways to prepare your yard for winter	helps prevent plant damage and ensures your yard is ready for spring	Facebook	Engaging	Long	t	t	draft	2025-04-18 18:25:14.555+00	\N	```json\n{\n  "content": "Winter is coming! ❄️ Is your yard ready? Taking a few steps now can make a HUGE difference in preventing plant damage and ensuring a vibrant, beautiful spring! Here's your ultimate guide to winterizing your yard:\\n\\n🍂 **Clean Up Those Leaves!** Matted leaves can suffocate your lawn and harbor pests/diseases. Rake 'em up! Compost them, use them as mulch (shredded!), or bag them for pickup.\\n\\n🌳 **Prune, Prune, Prune!** Late fall/early winter is the perfect time to prune dormant trees and shrubs. Remove dead, damaged, or crossing branches. This improves air circulation and promotes healthy growth in the spring. ✂️\\n\\n🌼 **Protect Perennials:** Tender perennials need extra protection! Add a layer of mulch (straw, shredded leaves, or pine needles) around the base of plants to insulate them from the cold. You can also use burlap wraps for extra sensitive plants. \\n\\n💧 **Water Deeply (One Last Time):** Before the ground freezes, give your trees, shrubs, and lawn a deep watering. This helps them stay hydrated throughout the winter. 🌊\\n\\n🧪 **Soil Test & Amend:** Fall is a great time to test your soil's pH and nutrient levels. Amend your soil with compost or other organic matter to improve its fertility for next year. 🌱\\n\\n🏡 **Winterize Irrigation Systems:** Drain and shut down your irrigation system to prevent pipes from freezing and bursting. Insulate exposed pipes. 🥶\\n\\n🌿 **Consider a Cover Crop:** For vegetable gardens, planting a cover crop (like rye or oats) can improve soil health, prevent erosion, and suppress weeds over the winter. \\n\\n🐦 **Don't Forget the Birds!** Leave some seed heads standing to provide food for birds during the winter months. Consider setting up a bird feeder and providing a source of fresh water. 🕊️\\n\\nBy taking these simple steps now, you'll be setting your yard up for success next spring! What are your favorite winterizing tips? Share them in the comments below! 👇\\n\\n#WinterizeYourYard #FallGardening #GardenTips #WinterPrep #LawnCare #Gardening #HomeImprovement #YardWork #PrepareForWinter #SpringIsComing #GardenLife #HealthyPlants #WinterGardening",\n  "title": "Get Your Yard Ready for Winter! ❄️🍂 Your Ultimate Guide!",\n  "visual_content_idea": "A collage of photos showcasing each of the winterizing tips: raking leaves, pruning branches, mulching plants, watering deeply, a soil test kit, draining an irrigation system, a cover crop, and a bird feeder."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0
16	aef8871f-cafb-48b5-a8ab-6c90c5a0fe63	Tips & Advice	Ways to prepare your yard for winter	helps prevent pland damange for spring	Facebook	Educational	Medium	t	f	draft	2025-04-22 09:43:17.739+00	\N	```json\n{\n  "content": "Winter is coming! 🥶 Prepare your yard now to prevent plant damage and ensure a beautiful spring bloom. 🌸\\n\\nHere are a few tips:\\n\\n*   **Clean up debris:** Rake leaves and remove dead plants to prevent mold and pests. 🍂\\n*   **Mulch:** Add a layer of mulch around your plants to insulate their roots. 🪵\\n*   **Protect vulnerable plants:** Cover delicate shrubs with burlap or plant covers. 🌿\\n*   **Winterize irrigation:** Drain your sprinkler system to prevent freezing and bursting pipes. 💧\\n\\nTaking these steps now will make a HUGE difference when springtime rolls around! 🌱",\n  "title": "Get Your Yard Winter-Ready!",\n  "visual_content_idea": "A split-screen image showing a neglected yard in the winter vs. a healthy yard in the spring, or an infographic with winter yard prep tips."\n}\n```	94ef9a8f-98e7-46ca-ad16-a9bbceef6ca6
17	b592525b-95bc-46f9-8924-d4f1e862aa2c	How-to Guide	how to sing and dance while worshipping Jarilo while getting the work done	they get to find out why we singe and dance and worship jarilo while getting the work done	Facebook	Professional	Long	t	f	draft	2025-04-23 13:19:33.176+00	\N	```json\n{\n  "content": "Embrace the Rhythms of Productivity: A Guide to Singing, Dancing, and Worshipping Jarilo While Achieving Your Goals\\n\\nMany find it challenging to balance spiritual practices with the demands of daily life. However, incorporating worship of Jarilo – the Slavic god of spring, fertility, and passion – into your workday can be surprisingly energizing and effective. This guide provides practical tips for integrating singing, dancing, and devotion into your routine, boosting productivity and fostering a deeper connection to the natural world.\\n\\n1. The Morning Ritual: Start your day with a brief sunrise salutation to Jarilo. A simple song of gratitude, accompanied by gentle movements emulating the awakening of spring, can set a positive and focused tone for the day. Even a minute or two can make a difference.\\n\\n2. Micro-Moments of Movement: Incorporate short bursts of dancing between tasks. Put on uplifting music (consider folk tunes or instrumental pieces that resonate with Jarilo's energy) and move your body freely for 5-10 minutes. This can break up monotony, improve circulation, and reignite your focus.\\n\\n3. Mindful Singing While Working: Engage in mindful singing while performing repetitive or less demanding tasks. Select simple chants or songs dedicated to Jarilo, focusing on the rhythm and melody. This can transform mundane activities into opportunities for spiritual connection and enhance your concentration.\\n\\n4. Desk Decorations: Adorn your workspace with symbols of Jarilo – images of springtime blooms, representations of horses, or even simple floral arrangements. These visual cues can serve as constant reminders of your devotion and inspire creativity.\\n\\n5. Nature Breaks: Take short breaks to connect with nature, if possible. Even a brief walk in a park or garden can revitalize you and strengthen your connection to Jarilo's domain. Offer a silent prayer of thanks for the bounty of the earth.\\n\\n6. Incorporate Red and White: Wear red and white clothing or accessories, Jarilo's colors, to feel more connected.\\n\\n7. Set Intentions: Before beginning a task, dedicate it to Jarilo. Visualize your work contributing to the flourishing of life and abundance. This can infuse your efforts with meaning and purpose.\\n\\nBy weaving these practices into your daily life, you can cultivate a harmonious balance between your spiritual devotion and professional responsibilities. Experience increased energy, improved focus, and a deeper appreciation for the vibrant energy of Jarilo. 🌿☀️🐎🎶\\n\\nRemember to adapt these suggestions to your own beliefs and work environment. The key is to find what resonates with you and allows you to connect with Jarilo in a meaningful and authentic way. \\n\\nWhy sing, dance, and worship Jarilo while working? Because it connects us to the cycles of nature, imbues our tasks with purpose, and reminds us of the inherent joy in creation. It transforms work from a chore into an act of devotion. This can lead to increased motivation, creativity, and a greater sense of fulfillment.",\n  "title": "Sing, Dance, and Work: A Guide to Integrating Jarilo Worship into Your Daily Routine",\n  "visual_content_idea": "A video montage showing someone working at a desk interspersed with shots of springtime nature, folk dancing, and artwork depicting Jarilo. The music would be upbeat and folky."\n}\n```	4a131143-f973-4f8d-8b4b-83fafedcf9df
18	c76551f9-9e78-4a5b-a09e-b1f475423939	Promotion	Bad grading in the backyard can lead to ruined landscaping and damage home foundations.	make sure the yard is sloped away from the home and pushed water away from buildings and expenscve hardscapes. 	Facebook	Engaging	Medium	t	f	draft	2025-05-15 18:00:06.724+00	\N	```json\n{\n  "content": "Is your yard's grading secretly sabotaging your home? 🏡 Bad grading can lead to water pooling around your foundation, ruining your landscaping, and even causing serious (and costly!) structural damage. 💧\\n\\nThe key is ensuring your yard slopes *away* from your home. This simple step directs water away from your foundation, protecting your hardscapes and keeping your basement dry! A properly graded yard will push water away from buildings and expensive hardscapes. Don't let poor grading become a nightmare! \\n\\nThinking about a landscaping project? Give us a call for a free consultation! We'll make sure your yard is beautiful *and* functional! 👍",\n  "title": "Protect Your Home From Bad Grading!",\n  "visual_content_idea": "Image or video showcasing a yard with proper grading, highlighting the slope away from the house and water runoff. Alternatively, show a split screen: one side with water pooling against a foundation and the other with proper drainage."\n}\n```	835c094d-bb0a-4ccc-97b0-228210ea817b
19	d6086b2b-1e09-48d3-a9f9-e3f6967d7158	Promotion	finsiehd a gravel driveway on morion.  no more bumping trips in and out.  Dann lovesd the look too	proper driveways look great	Facebook	Engaging	Short	t	f	draft	2025-05-22 16:10:35.298+00	\N	```json\n{\n  "content": "Finished a gravel driveway on morion! No more bumping trips in and out. Dann loves the look too! 😍 Proper driveways look great and add value! 🏡✨",\n  "title": "New Gravel Driveway!",\n  "visual_content_idea": "Before & After photos of the gravel driveway. Include Dann (with permission) smiling in the 'After' photo."\n}\n```	835c094d-bb0a-4ccc-97b0-228210ea817b
\.


--
-- Data for Name: estimates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.estimates (id, "projectName", "serviceType", "problemDescription", "solutionDescription", "projectEstimate", "projectStartDate", "projectEndDate", "lineItems", "equipmentMaterials", "additionalNotes", total_amount, created_at, status, ai_generated_estimate, user_id, client_id, updated_at, type) FROM stdin;
3c6d4436-46ee-4f66-9a84-74a2bf999457	Landscape	Rock Driveway	Wash out	Rake, install & grade gravel	2500	2025-06-03T05:00:00.000Z	2025-06-04T05:00:00.000Z	[{"id": 1, "quantity": 2, "unitPrice": 50, "totalPrice": 100, "description": "1233"}]			100	2025-05-30 18:02:00.955+00	pending	```json\n{\n  "projectOverview": "We are pleased to provide this project estimate for a refreshed and resilient rock driveway at your residence. Our solution directly addresses the current washout issues, enhancing both the functionality and curb appeal of your property. A properly graded and installed gravel driveway will minimize future erosion and provide a durable surface.",\n  "scopeOfWork": "- Rake the existing driveway area to prepare the base.\\n- Install and grade new gravel to ensure proper drainage and a level surface.\\n- Compact the gravel to enhance stability and longevity.",\n  "timeline": "The project is expected to take 1 day (1 week) for completion.",\n  "pricing": "The total cost for the project is $2500. This pricing is all-inclusive and covers all labor and material costs associated with the scope of work outlined above. There are no hidden fees."\n}\n```	71fbf873-af4f-4f51-95f1-153ba64776e3	4c1b10bb-e53f-4ff8-8127-8aeda4d7982d	\N	residential
c517aa79-8476-4b7b-970c-10acc1468126	Wolf	Excavation	Drainage Solution	Trench System	2000	2025-04-16T18:30:00.000Z	2025-04-19T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 200, "totalPrice": 200, "description": "Shoes and Gravel"}]	Shoes and Gravel and Covers	Discounts available	200	2025-04-01 13:50:45.663+00	pending	{"projectOverview":"tharun kumar panga We are pleased to provide this estimate for Project Wolf, tailored to meet the residential excavation needs of Azhar Mohammed. This project addresses critical drainage issues by implementing an effective trench system, safeguarding your property from potential water damage and ensuring long-term stability.","scopeOfWork":["Excavation of trenches according to specified dimensions and site plans.","Installation of drainage materials including shoes, gravel, and covers.","Ensuring proper grading and slope for optimal water flow.","Site cleanup and restoration to pre-excavation conditions.","Final inspection to guarantee system functionality and adherence to safety standards.","New scope itemsss"],"timeline":"The project is expected to take approximately 1 week (3 days) for completion, starting from the agreed-upon commencement date.","pricing":"The total cost for Project Wolf is $2000. This price includes all labor, materials (shoes, gravel, and covers), equipment, and site cleanup as detailed in the scope of work. Please inquire about available discounts."}	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	67e56aaa-0e04-4d61-8834-61e4c80f3f99	2025-04-14	\N
64dbcba2-2430-4e08-8527-c68c96b295a8	Window 	Drainage	Installing a drainage solution to prevent yard flooding	Installing a trench system to divert water away from house	2000	2025-04-09T18:30:00.000Z	2025-04-24T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes "}]	Shoes and Gravel	Discounts available	2000	2025-04-01 18:10:07.121+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate to Azhar Mohammed for the installation of a comprehensive drainage solution at your residence. Addressing the issue of yard flooding, our proposed solution will safeguard your property and enhance its value by effectively managing excess water and preventing potential water damage.",\n  "scopeOfWork": "- Conduct a thorough site assessment to determine the optimal trench system layout.\\n- Excavate and prepare the trench for the drainage system.\\n- Install a gravel base within the trench to facilitate water filtration and flow.\\n- Install the trench drain system to divert water away from the house.\\n- Backfill the trench, ensuring proper compaction and grading for optimal drainage.\\n- Final site cleanup, restoring the affected area to its original condition or better.\\n- Dispose of all waste materials responsibly.",\n  "timeline": "The project is expected to take 3 weeks (15 days) for completion.",\n  "pricing": "The total cost for the project is $2000. This pricing includes all labor, materials (including shoes and gravel), and equipment necessary for the complete installation of the drainage system. Please inquire about available discounts."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N	\N	\N
bbe719db-59a6-4072-a0fe-81cc0b16bd84	Shoes	Excavation	Excavation of Dump 	Installing Dumpyard	3500	2025-04-08T18:30:00.000Z	2025-04-09T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 500, "totalPrice": 500, "description": "Gravel"}]	Excavator	Discounts available	3500	2025-04-01 18:15:27.023+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate to Ryan for the excavation and installation of a dumpyard at your commercial property. Addressing the need for proper waste management, our solution will provide a designated area, enhancing the efficiency and safety of your site operations.",\n  "scopeOfWork": "- Site assessment and preparation for dumpyard installation.\\n- Excavation of the designated area for the dumpyard, removing existing waste and debris.\\n- Leveling and compacting the excavated area to ensure a stable base.\\n- Installation of the dumpyard structure, ensuring proper drainage and containment.\\n- Final site cleanup and debris removal.",\n  "timeline": "The project is expected to take approximately 1 day (1 week) for completion, contingent upon weather conditions and site accessibility.",\n  "pricing": "The total cost for this project is $3500. This pricing is all-inclusive, covering labor, equipment (including the excavator), and materials. Discounts are available upon request."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N	\N	\N
d670a38f-a21b-4757-85f6-e2c6b6c58780	new 	Drainage	Installing a drainage solution to prevent yard flooding	Installing a trench to divert water awway from house	3000	2025-04-02T18:30:00.000Z	2025-04-04T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes and Gloves"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Machine"}]	Shoes, Gravel, Gloves	Discounts available on bulk orders	3000	2025-04-05 19:34:33.129+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for your residential drainage solution. This solution will effectively address the yard flooding issues you are experiencing by diverting water away from your house, protecting your property and preventing potential water damage.",\n  "scopeOfWork": "- Excavate a trench along the designated area to facilitate water diversion.\\n- Install a gravel-filled trench to promote proper drainage.\\n- Ensure proper grading and slope to direct water away from the house.\\n- Backfill and compact the soil to restore the landscape.",\n  "timeline": "The project is expected to take 2 days (1 week) for completion.",\n  "pricing": "The total cost for the project is $3000. This pricing is all-inclusive with no hidden fees. Discounts are available on bulk orders."\n}\n```	961af7eb-1a61-47ac-9fd4-e8174218a32f	e63f515e-2515-4c76-b79a-b639b35e1327	\N	\N
b5312352-a9d4-4d8f-a4de-e3c896e4418a	Niloufer	Excavation	Excavating Mines	Removing Mines infront of House	3500	2025-04-08T18:30:00.000Z	2025-04-10T18:30:00.000Z	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Shoes and Gravel	Discounts available for bulk orders	320	2025-04-01 14:47:53.589+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for Niloufer, tailored specifically for Azhar Mohammed. Addressing the critical need to remove mines obstructing your property, our expert excavation service will ensure a safe and clear path forward, restoring the value and peace of mind associated with your land.",\n  "scopeOfWork": "- Conduct a thorough site assessment and safety briefing.\\n- Carefully and systematically remove all identified mines from the designated area in front of the house.\\n- Dispose of the removed mines according to all applicable safety regulations and legal requirements.\\n- Backfill and level the excavated area with gravel to ensure stability and a restored landscape.\\n- Conduct a final site inspection to confirm complete mine removal and site safety.",\n  "timeline": "The project, Niloufer, is expected to take approximately 2 days (1 week) for completion, depending on the weather.",\n  "pricing": "The total cost for the Niloufer project is $3500. This pricing is all-inclusive, encompassing labor, equipment, mine disposal fees, materials (shoes and gravel), and site restoration. Please note that discounts are available for bulk orders or additional projects."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897	\N	\N
6a77a3f2-c571-4ee5-b8db-199ab54d61c4	purna project	drainage	installing a drainage	installing a trench	2000	2025-04-14T18:30:00.000Z	2025-04-16T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "shoes"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "gravel"}]	shoes and gravel	huge discounts on bulk orders	2000	2025-04-18 11:15:01.54+00	pending	{"projectOverview":"We are pleased to present this project estimate for your residential drainage installation. Addressing drainage issues promptly is crucial for protecting your property's foundation and preventing water damage. Our trench drain solution will effectively manage water runoff, ensuring a dry and safe environment for your home.","scopeOfWork":["Excavation and preparation of the trench area.","Installation of a high-quality trench drain system.","Backfilling the trench with gravel for optimal drainage.","Ensuring proper slope and outflow for efficient water management.","Final inspection and site cleanup.","New scope item"],"timeline":"The project is expected to take 1 week (2 days) for completion.","pricing":"The total cost for the project is $2000. This pricing is all-inclusive and covers all labor, materials (shoes, gravel), and equipment necessary for the successful completion of the trench drain installation. Please inquire about potential discounts for bulk orders."}	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	5e491541-f3cf-4730-a555-e1a9b3fe075a	2025-04-18	residential
d199c128-0dc4-4024-af95-bf835ed793ea	Pink	drainage	Installing a drainage solution to prevent yard flooding	Installing a trench to divert water away from the house	3000	2025-04-16T18:30:00.000Z	2025-04-29T18:30:00.000Z	[{"id": 1, "quantity": 2, "unitPrice": 1000, "totalPrice": 2000, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Gravel"}, {"id": 3, "quantity": 1, "unitPrice": 0, "totalPrice": 0, "description": "New item"}]	Shoes and Gravel	High Discounts on Bulk Orders	3000	2025-04-17 10:58:09.164+00	pending	{"projectOverview":"We are happy to present this project estimate for the installation of a drainage solution at your commercial property. Excessive yard flooding can cause significant damage to your property's foundation and landscaping. Our proposed trench drainage system will effectively divert water away from the building, mitigating these risks and preserving the integrity of your commercial space.","scopeOfWork":["Excavate a trench along the designated area to redirect surface water flow.","Install a gravel bed within the trench to facilitate optimal water drainage.","Install a suitable drainage pipe within the gravel bed, ensuring proper slope and connection to the designated outflow point.","Backfill the trench with additional gravel and soil, ensuring proper compaction and a level surface.","Procure and utilize necessary materials, including gravel and specialized drainage pipes.","Clean up the project site, removing any excess soil, debris, or waste materials. We will provide the needed safety shoes for the work.","New scope item"],"timeline":"The project is expected to take approximately 2 weeks (13 days) for completion, weather permitting.","pricing":"The total cost for the project is $3000. This pricing is all-inclusive with no hidden fees and includes all labor, materials (including gravel and drainage pipes), and site cleanup. Please note that we offer high discounts on bulk orders, which we would be happy to discuss further."}	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327	2025-04-17	commercial
179866c0-792c-4767-a564-a895b0d47534	heroics	drainage	Installing a drainage solution to prevent yard flooding	Installing a trench system to divert water away from the house	3000	2025-04-15T18:30:00.000Z	2025-04-16T18:30:00.000Z	[{"id": 1, "quantity": 2000, "unitPrice": 1, "totalPrice": 2000, "description": "Shoes"}, {"id": 2, "quantity": 500, "unitPrice": 2, "totalPrice": 1000, "description": "Gravel"}]	Shoes and Gravel	Discounts available on Bulk Orders	3000	2025-04-17 11:36:27.415+00	pending	{"projectOverview":"We are oerng to present this project estimate for the 'Heroics' drainage solution. Your property's susceptibility to yard flooding will be addressed effectively with our proposed trench drain system, protecting your foundation and landscaping from water damage.","scopeOfWork":["Excavation of a trench along the designated area to redirect water flow.","Installation of a high-quality trench drain system designed to efficiently capture and divert surface water.","Backfilling the trench with gravel to promote drainage and ensure stability.","Proper grading and leveling to ensure optimal water flow towards the drainage outlet.","Site cleanup, including the removal of excavated soil and debris.","New scope item"],"timeline":"The project is expected to take approximately 1 day (1 week) for completion, weather permitting.","pricing":"The total cost for the 'Heroics' drainage solution is $3000, which includes all labor, materials (shoes and gravel), and equipment necessary for the project. This pricing is all-inclusive with no hidden fees. Discounts are available on bulk orders."}	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327	2025-04-17	commercial
a0ef366b-dec9-45d2-aa5d-617f95ffe12c	rajan	drainage	installing a drainage system to prevent yard flooding	installing a trench to divert water away from the house	4000	2025-04-17T18:30:00.000Z	2025-04-19T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "shoes"}, {"id": 2, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "gravel"}]	shoes and gravel and gloves	huge discounts on bulk orders	4000	2025-04-18 16:18:12.688+00	pending	{"projectOverview":"We are happy to present this project estimate for installing a drainage system at your residence. This solution will effectively address the recurring issue of yard flooding by diverting excess water away from your house, protecting your property and landscaping.","scopeOfWork":["Excavate a trench along the perimeter of the property to intercept surface water runoff.","Install a gravel-filled trench drainage system to efficiently collect and channel water.","Ensure proper grading and slope within the trench to facilitate optimal water flow.","Connect the trench to a designated discharge point, diverting water away from the house foundation.","Backfill the trench with gravel and soil, restoring the landscape to a visually appealing condition."],"timeline":"The project is expected to take 2 days (1 week) for completion, from commencement to final inspection.","pricing":"The total cost for the project is $4000. This pricing is all-inclusive and covers all labor, materials (including gravel, geosynthetic fabric, and necessary tools), equipment, and site cleanup. We also offer huge discounts on bulk orders; inquire to learn more."}	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	68d2d543-f52a-4130-a457-5471bf8a2856	2025-04-18	residential
4a31e79b-d507-4603-9650-b86f332aca7e	samson	drainage	installing a drainage system to prevent yard flooding	installing a trench to divert water away from house	3000	2025-04-16T18:30:00.000Z	2025-04-24T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "shoes"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "gravel"}, {"id": 3, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "gloves"}]	shoes,gravel,gloves	huge discounts available on bulk orders	3000	2025-04-18 16:26:49.407+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for the Samson drainage system installation. This solution will effectively address your yard flooding issues by diverting water away from your house, protecting your property and preventing potential water damage. Our expertise in residential drainage solutions ensures a long-lasting and reliable system.",\n  "scopeOfWork": "- Excavate a trench along the designated area to facilitate water diversion.\\n- Install a gravel bed within the trench to promote proper drainage and filtration.\\n- Lay drainage pipes within the trench, ensuring proper slope and connections.\\n- Backfill the trench with appropriate materials, ensuring proper compaction and stability.\\n- Final grading and landscaping to restore the affected area to its original condition or better.\\n- Procure all necessary materials, including gravel, pipes, and landscaping supplies (shoes, gloves).",\n  "timeline": "The project is expected to take 2 weeks (8 days) for completion.",\n  "pricing": "The total cost for the project is $3000. This pricing is all-inclusive with no hidden fees. Please note that huge discounts are available on bulk orders."\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	1a3c96b2-5920-4dce-8543-f40ce3e32cf1	\N	residential
c5201dc5-30bf-4fa4-b395-ae6c01bfa280	Project Zak	Drainage	Installing a drainage to prevent yard flooding	Installing a trench system to divert water away from house	4000	2025-04-09T18:30:00.000Z	2025-04-16T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoe and Gloves"}, {"id": 2, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Gravels"}]	Shoes, Gloves, Gravel	Huge Discounts avilable on Bulk Orders	4000	2025-04-18 18:11:28.501+00	pending	{"projectOverview":"We are happy to present this project estimate for Project Zak. Our drainage solution will effectively address your yard flooding issues by strategically diverting water away from your house, preventing water damage and preserving the integrity of your landscape.","scopeOfWork":["Excavation and preparation of trench for drainage system.","Installation of trench system using gravel for optimal water flow.","Proper grading to ensure effective water diversion away from the house.","Site cleanup and restoration after installation.","Disposal of excess soil","Debris"],"timeline":"The project is expected to take 1 week (7 days) for completion.","pricing":"The total cost for Project Zak is $4000. This pricing is all-inclusive, covering labor, materials (including shoes, gloves, and gravel), and site cleanup. Huge Discounts available on Bulk Orders"}	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	839b6b01-af69-4d9c-baab-efebe14e67db	2025-04-18	commercial
d0e1ae4b-c320-492c-bdee-d6488b6a01ed	Home	excavation	installing a drainage solution to prevent yard flooding	installing a trench system to divert water away from the house	3000	2025-04-09T18:30:00.000Z	2025-04-15T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "shoes"}]	shoes, gravel, sand	hge discounts on bulk orders	3000	2025-04-18 19:06:20.913+00	pending	```json\n{\n  "projectOverview": "We are pleased to provide this estimate for your residential excavation project, focused on resolving the yard flooding issue at your home. Our proposed drainage solution will effectively divert water away from your property, preventing future water damage and enhancing your property's usability.",\n  "scopeOfWork": "- Excavation of trenches to the specified dimensions for the drainage system.\\n- Installation of a trench system designed to effectively divert water away from the house.\\n- Placement of geotextile fabric lining within the trenches.\\n- Layering of gravel and sand within the trenches to ensure proper drainage and filtration.\\n- Backfilling of excavated areas and restoration of the surrounding landscape to a neat and tidy condition.\\n- Removal and disposal of all excavated materials and debris.",\n  "timeline": "The project is expected to take 1 week (6 days) for completion.",\n  "pricing": "The total cost for the project is $3000. This pricing is all-inclusive, covering labor, equipment, materials (including shoes, gravel, and sand), and site cleanup. Furthermore, we offer significant discounts on bulk material orders, potentially leading to further cost savings. "\n}\n```	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	19520e84-fe1a-4742-8bf1-0586bcf6f0c0	\N	residential
01b25541-a7fe-4a9b-8f1a-c3301aaae32c	Road Project	Excavation	Building a road of 100 feet in 2 km	Need to construct a road with minimal time with good equipment	10000	2025-04-22T05:00:00.000Z	2025-04-30T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 5000, "totalPrice": 5000, "description": "Excavator"}, {"id": 2, "quantity": 1, "unitPrice": 5000, "totalPrice": 5000, "description": "Gravel"}]	Thar, Soil, Excavator, Road machine, shoes, gloves	The road life should long last and it withstand all weather conditions.	10000	2025-04-19 15:21:03.45+00	pending	{"projectOverview":"We are pleased to provide this estimate for the construction of your crucial road project. Our proposed solution focuses on efficient and durable road construction techniques to deliver a high-quality road that meets your requirements, minimizes disruption, and withstands all weather conditions, ensuring long-lasting performance.","scopeOfWork":["Excavation of the designated road path (2 km in length, 100 feet wide).","Supply and placement of base layer soil for road foundation.","Application of Thar (asphalt) for road surface.","Utilization of heavy machinery including Excavators and Road Machines for efficient construction.","Provision of necessary safety equipment including shoes and gloves for our personnel.","Compaction and grading of the road surface to ensure optimal smoothness and drainage.","Quality control checks throughout the project to guarantee adherence to specified standards."],"timeline":"The project is expected to take 2 weeks (8 working days) for completion, commencing upon approval and resource mobilization.","pricing":"The total cost for the road project is $10,000. This pricing includes all labor, materials (Thar, Soil, etc.), equipment rental, and associated expenses. It is an all-inclusive price with no hidden fees."}	d9432cc7-89b9-45ab-9ffc-365a86939107	6f9d9ba9-3755-434f-9dcf-d960e3253c62	2025-04-19	commercial
aef8871f-cafb-48b5-a8ab-6c90c5a0fe63	teste1	excavation	installing a drainage solution	installing a trench system to divert water	5000	2025-04-23T22:00:00.000Z	2025-04-29T22:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 250, "totalPrice": 250, "description": "Materials"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Work"}]	skid steer		1250	2025-04-22 09:39:06.994+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for the excavation work required to install a drainage solution at your residential property. Addressing water accumulation issues can prevent costly damage and improve the overall functionality and value of your property. Our proposed trench system will effectively divert water away from critical areas, ensuring long-term protection.",\n  "scopeOfWork": "- Site assessment to determine optimal trench placement for effective water diversion.\\n- Excavation of trenches to specified dimensions, ensuring proper depth and slope for drainage.\\n- Installation of drainage materials within the trenches to facilitate water flow.\\n- Backfilling and compaction of excavated areas, restoring the landscape to a neat and functional condition.\\n- Skid steer operation for efficient material handling and excavation.",\n  "timeline": "The project is expected to take 6 days (approximately 1 week) for completion, weather permitting.",\n  "pricing": "The total cost for the project is $5000. This pricing includes all labor, equipment rental (skid steer), materials, and site cleanup. There are no hidden fees; this is a comprehensive cost for the complete drainage solution installation."\n}\n```	94ef9a8f-98e7-46ca-ad16-a9bbceef6ca6	5f894019-d57e-47dc-aa3e-3bd0464e9ef1	\N	residential
b592525b-95bc-46f9-8924-d4f1e862aa2c	logging	Excavation	his yard is flooding all the time, he needs a solution	install a trench so the water flows better	50000	2025-04-09T22:00:00.000Z	2025-04-29T22:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 50000, "totalPrice": 50000, "description": ""}]	a skidsteer, shovels, and good old power of will	We might sing and dance while we're doing it	50000	2025-04-23 13:14:26.116+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for a comprehensive drainage solution on your property. Excessive flooding can lead to property damage and decreased usability of your yard. Our proposed trenching solution will effectively manage stormwater runoff, redirecting water flow and mitigating the risk of future flooding, thereby enhancing the value and usability of your property.",\n  "scopeOfWork": "- Excavation of a trench according to the agreed-upon design and specifications.\\n- Strategic placement of the trench to effectively capture and redirect stormwater runoff.\\n- Utilization of a skid steer for efficient excavation and material handling.\\n- Manual labor using shovels for precise trench shaping and detail work.\\n- Backfilling and compaction of the trench to ensure structural integrity.\\n- Final grading and site cleanup to restore the landscape to an aesthetically pleasing condition.\\n- Material procurement, including necessary drainage aggregates.",\n  "timeline": "The project is expected to take approximately 3 weeks (20 days) for completion, contingent upon weather conditions and unforeseen site complexities.",\n  "pricing": "The total cost for the project is $50,000. This pricing includes all labor, materials (skid steer rental, shovels, and aggregate), equipment operation, site preparation, and post-construction cleanup. This pricing is all-inclusive, ensuring transparency and no hidden fees. While labor is our main asset, we might sing and dance while we're doing it."\n}\n```	4a131143-f973-4f8d-8b4b-83fafedcf9df	3afba4f2-cd52-47f1-b9e6-c05130557a07	\N	commercial
c76551f9-9e78-4a5b-a09e-b1f475423939	Deemer - Backyard Grading - May 2025	grading backyard	backyard is sloped towards the house.  This is caausing issues woth water and their foundation.  	We will completyey regrade the entire yard so water properly drains away from the house and towards the wooded edge of the yard.  We will use a laser system to stay on grade abnd maintain the proper slope.  Once the yard is graded properly we will grass seed the entire yard and spead straw on top to keep the seed in place.  when we leave the only thing thge custoer will hgave to do is water the yard.	4800	2025-05-06T05:00:00.000Z	2025-05-13T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 3500, "totalPrice": 3500, "description": "Grading Services "}, {"id": 2, "quantity": 1, "unitPrice": 1300, "totalPrice": 1300, "description": "Grass seeding and Straw"}]		They do not need to be home for us to do the work.  We will have the entire project completed before they get home from work. 	4800	2025-05-13 21:07:45.874+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for your backyard regrading. This comprehensive solution will address the existing slope issue causing water damage to your foundation. Our expert grading will ensure proper drainage away from your home, protecting your investment and providing peace of mind.",\n  "scopeOfWork": "- Thoroughly regrade the entire backyard to establish proper drainage away from the house.\\n- Utilize a laser grading system to maintain accurate slope and prevent water pooling.\\n- Direct water flow towards the wooded edge of the yard, away from the foundation.\\n- Apply grass seed evenly across the regraded area.\\n- Spread a layer of straw to protect the seed and promote germination.\\n- Complete all work without requiring your presence on-site.",\n  "timeline": "The project is expected to take 1 week (7 days) for completion.",\n  "pricing": "The total cost for the project is $4800. This pricing is all-inclusive and covers all labor, materials, and equipment necessary to complete the regrading and seeding as outlined in the scope of work. There are no hidden fees."\n}\n```	835c094d-bb0a-4ccc-97b0-228210ea817b	44652c5e-c833-422c-bcc1-1b848646d2f6	\N	residential
d6086b2b-1e09-48d3-a9f9-e3f6967d7158	Morgan - Driveway Repair	driveway repair	grvel is full og potholes and ruttee.  driveway needs graded and 20 tons of ca6 rock laid as a fisbh cosat	grade tge drivewya to remove imperfections and privide a solid base for the =new ca6.  	3500	2025-05-27T05:00:00.000Z	2025-05-27T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 3500, "totalPrice": 3500, "description": "gravel "}]			3500	2025-05-22 16:06:10.379+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for your residential driveway repair. Our solution will restore your driveway to a smooth and durable surface, eliminating potholes and ruts and improving the overall appearance and functionality of your property. Addressing these issues will not only enhance curb appeal but also prevent further damage and potential hazards.",\n  "scopeOfWork": "- Grade the existing driveway surface to remove imperfections and establish a solid, even base.\\n- Deliver and spread approximately 20 tons of CA6 rock, creating a fish coat layer.\\n- Ensure proper compaction and grading of the new CA6 rock layer for optimal stability and drainage.",\n  "timeline": "The project is expected to take 0 weeks for completion.",\n  "pricing": "The total cost for the project is $3500. This pricing is all-inclusive with no hidden fees."\n}\n```	835c094d-bb0a-4ccc-97b0-228210ea817b	1a00e395-fb2d-48f3-a7f5-46754937796e	\N	residential
d1c2e8da-8b03-418b-91fa-87f763f879a1	Dan Morgan - Yard Grading	Grading of Backyard	Water runs towrds the house,  needs to flow towards the ravine	we will grade the yard to make the dirt lower than the sill plate and flow water when it rains towrds the ravine. We iwll also grass seed the lawn and lay straw.  (I need this estiamte written in spanish)	5000	2025-05-28T05:00:00.000Z	2025-05-29T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 5000, "totalPrice": 5000, "description": "YArd Grading"}]			5000	2025-05-22 17:34:31.871+00	pending	```json\n{\n  "projectOverview": "Nos complace presentar este presupuesto para su proyecto de mejora del patio trasero. Nuestra solución abordará eficazmente el problema del drenaje del agua, protegiendo su hogar de posibles daños y mejorando la usabilidad de su jardín. Al dirigir el agua de lluvia hacia la barranca, evitaremos que el agua se acumule cerca de la casa y cause problemas de humedad.",\n  "scopeOfWork": "- Nivelación del terreno del patio trasero para asegurar un flujo adecuado del agua hacia la barranca.\\n- Asegurar que la pendiente del terreno sea inferior al nivel del umbral de la casa para evitar la acumulación de agua cerca de los cimientos.\\n- Siembra de semillas de césped en el área nivelada.\\n- Aplicación de paja para proteger las semillas y promover la germinación.",\n  "timeline": "Se estima que el proyecto se completará en 1 día (1 semana).",\n  "pricing": "El costo total del proyecto es de $5000. Este precio incluye todos los materiales y la mano de obra necesarios para completar el trabajo descrito. No hay cargos ocultos."\n}\n```	835c094d-bb0a-4ccc-97b0-228210ea817b	1a00e395-fb2d-48f3-a7f5-46754937796e	\N	residential
cb5bd64a-f5ab-4ab2-bbfc-0663024e0d84	Point Aqurius	demo of current structure and building of a new building out of the flood way 	build a better structure for long term use 	will demo current building and depose of properly \nwill build to correct height dirt pad \nthen pour a 5 inch slab with 12-18 inch footers 	62306	2025-06-10T05:00:00.000Z	2025-06-24T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 7500, "totalPrice": 7500, "description": "demo of current building "}, {"id": 2, "quantity": 1, "unitPrice": 11000, "totalPrice": 11000, "description": "new concrete slab "}, {"id": 3, "quantity": 1, "unitPrice": 9000, "totalPrice": 9000, "description": "build out of new bathroom and office "}, {"id": 4, "quantity": 1, "unitPrice": 20006, "totalPrice": 20006, "description": "24x40 with 20ft covered parkinking area "}, {"id": 5, "quantity": 1, "unitPrice": 6000, "totalPrice": 6000, "description": "plumbing "}, {"id": 6, "quantity": 1, "unitPrice": 4800, "totalPrice": 4800, "description": "eletrical"}, {"id": 7, "quantity": 1, "unitPrice": 4000, "totalPrice": 4000, "description": "dirt pad for new build "}]	dumpsters , excavator , skid steer, roller , concrete , metal shop material 	bid number are only good for 15days from submission due to unstable market 	62306	2025-06-12 17:52:02.775+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for the Point Aqurius project. Our solution will effectively address your need for a resilient and long-lasting residential structure, built outside the floodway, ensuring the safety and longevity of your property.",\n  "scopeOfWork": "- Demolition of the existing structure and proper disposal of all debris according to environmental regulations.\\n- Preparation of a dirt pad to the correct height for the new construction, ensuring proper elevation and drainage.\\n- Pouring a 5-inch concrete slab with reinforced 12-18 inch footers for a solid and stable foundation.\\n- Procurement and utilization of necessary materials, including dumpsters, excavator, skid steer, roller, concrete, and metal shop materials, to complete the project efficiently and effectively.",\n  "timeline": "The project is expected to take 14 days (2 weeks) for completion.",\n  "pricing": "The total cost for the Point Aqurius project is $62306. This pricing is all-inclusive, covering all labor, materials, and equipment necessary to complete the project as described. Please note that this bid is valid for 15 days from submission due to market instability."\n}\n```	d194c33a-5679-4dcb-b22c-fac98cfec3cf	ce5d7952-77f7-4578-8c4a-4c94c669dd2b	\N	residential
b181cb14-a933-4db7-b313-10aa5a7b23d0	140 quiet springs retention wall install	demo 171ft of existing retaining wall and install new concrete wall . this is due to inproper install from home builder 	failing retention wall installed  by home builder 	demo existing all . and pour new wall with concrete . wall will be approx 40 inches tall with a 12 inch deep footer . wall will be approx 9 inches wide 	19165	2025-06-20T05:00:00.000Z	2025-06-20T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 17000, "totalPrice": 17000, "description": "171ft of concrete retaining wall"}, {"id": 2, "quantity": 1, "unitPrice": 1500, "totalPrice": 1500, "description": "demo of existing wall"}]	skid steer , excavator , forum boards , concrete  , rebar 		18500	2025-06-17 12:16:55.112+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for the 140 Quiet Springs Retention Wall Installation. Our solution will effectively address the failing retaining wall installed by the home builder, providing a structurally sound and aesthetically pleasing replacement that ensures the long-term stability of your property.",\n  "scopeOfWork": "- Demolition and removal of the existing 171ft failing retaining wall.\\n- Excavation and preparation of the site for the new retaining wall.\\n- Construction of a new concrete retaining wall, approximately 40 inches tall and 9 inches wide.\\n- Installation of a 12-inch deep concrete footer for enhanced stability.\\n- Reinforcement of the wall with rebar for added structural integrity.\\n- Backfilling and grading around the new retaining wall to ensure proper drainage.\\n- Site cleanup and debris removal upon project completion.",\n  "timeline": "The project is expected to take approximately 2 weeks for completion.",\n  "pricing": "The total cost for the project is $19165. This pricing is all-inclusive, covering all labor, materials (including skid steer, excavator, form boards, concrete, and rebar), equipment rental, and site cleanup, with no hidden fees."\n}\n```	d194c33a-5679-4dcb-b22c-fac98cfec3cf	554217bb-a320-4b76-b4b1-df4e54012176	\N	residential
384b8fc8-590c-40dd-b5d6-08350d2387cf	New driveway 	Install new driveway to barn approach 	Install new 60’x30’ driveway from existing drive to barn slab	Cut out 4”-6” of existing dirt and leave on site in pasture. Install 3” of 1x3 recycled Conrete base rock. Install 3” of CA-6 white rock, grade and compact CA-6 with roller 	2750	2025-06-17T05:00:00.000Z	2025-06-18T05:00:00.000Z	[]	Skid loader, 1x3 recycled rock, CA-6 white rock 	20% due at contract signing and remainder due at project completion 	0	2025-06-01 22:59:54.636+00	pending	{"projectOverview":"We are pleased to present this project estimate for the installation of a new driveway at your property. This new driveway will provide a durable and aesthetically pleasing access point from your existing drive to your barn slab, enhancing functionality and potentially increasing your property value by providing easy access to the barn.","scopeOfWork":["Cut out 4\\"-6\\" of existing dirt along the planned driveway area (60' x 30') and leave the excavated material on-site in the designated pasture area.","Install a 3\\" base layer of 1x3 recycled concrete base rock across the entire driveway area.","Install a 3\\" top layer of CA-6 white rock over the base rock.","Grade the CA-6 white rock to ensure a smooth and even surface.","Compact the CA-6 white rock with a roller to achieve optimal stability and longevity of the driveway."],"timeline":"The project is expected to take approximately 1 day to complete.","pricing":"The total cost for this project is $2750. This includes all labor, materials (skid loader, 1x3 recycled rock, and CA-6 white rock), equipment, and compaction required to complete the driveway installation. 20% of the total cost is due at contract signing, with the remaining balance due upon project completion."}	7db369b9-1144-4395-931d-abf2b3b4a4ea	1047650c-dc8a-4506-b3ea-c945e007b2e9	2025-06-01	residential
003c4acd-80bb-4db9-b44f-e33ae8fad7cc	Peach Creek Farms concrete wash out repair 	concrete spillway repair 	under slab water erosion	saw cut leaking expansion joints foam fill and apply sealer compound on topical area 	800	2025-06-20T05:00:00.000Z	2025-06-21T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 800, "totalPrice": 800, "description": "materials and time "}]			800	2025-06-19 12:27:31.865+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for the concrete spillway repair at Peach Creek Farms. Our solution will address the underlying issue of water erosion, protecting your property's foundation and preventing further damage. By effectively sealing the leaking expansion joints, we aim to eliminate water intrusion and ensure the long-term stability of your concrete spillway.",\n  "scopeOfWork": "- Saw cut the existing leaking expansion joints to create a clean and optimal surface for repair.\\n- Inject expanding foam beneath the slab to fill voids and stabilize the soil, preventing further water erosion.\\n- Apply a high-quality sealant compound to the topical area of the repaired expansion joints to create a durable, waterproof barrier.",\n  "timeline": "The project is expected to take 1 day (approximately 1 week factoring in potential weather delays) for completion.",\n  "pricing": "The total cost for the concrete spillway repair project at Peach Creek Farms is $800. This pricing is all-inclusive, covering labor, materials, and equipment, with no hidden fees."\n}\n```	d194c33a-5679-4dcb-b22c-fac98cfec3cf	e05439e8-1d83-4a4e-910b-33376625a2b1	\N	residential
76ef16f5-cc7b-4b19-8f5e-29d2354deb1e	Meadow Rd clearing 	land clearing 2 acres 	clearing land for new build construction 	will underbrush unwanted vegetation and trees	9000	2025-06-24T05:00:00.000Z	2025-06-28T05:00:00.000Z	[{"id": 1, "quantity": 2, "unitPrice": 4500, "totalPrice": 9000, "description": "price per acre "}]	excavator 	50% deposit required . remainder due day of completion 	9000	2025-06-21 12:33:29.388+00	pending	```json\n{\n  "projectOverview": "We are pleased to provide this project estimate for the Meadow Rd land clearing project. This project will prepare your 2-acre residential lot for new construction by removing unwanted vegetation and trees, saving you time and ensuring a smooth building process.",\n  "scopeOfWork": "- Clear 2 acres of land on Meadow Rd.\\n- Underbrush all unwanted vegetation, including small trees and shrubs.\\n- Remove trees, ensuring proper disposal of debris.\\n- Utilize an excavator for efficient and effective clearing.\\n- Ensure the property is ready for construction to begin.",\n  "timeline": "The project is expected to take 1 week (4 days) for completion.",\n  "pricing": "The total cost for the Meadow Rd land clearing project is $9,000. This includes all labor, equipment (including the excavator), and debris removal. A 50% deposit is required upfront, with the remaining balance due upon completion of the project."\n}\n```	d194c33a-5679-4dcb-b22c-fac98cfec3cf	4435a254-a5aa-4bb7-8bb6-cc158da48bbe	\N	residential
d714663a-c0e2-457d-93a2-d6f62ed5a5e5	Driveway Repair	Rerock existing driveway	Fix water hole and install new rock over entire driveway	cur out grass and weeds off 125'x10' driveway and haul off. Provide, install, and compact about 3" of recycled asphalt over existing driveway	1600	2025-06-24T05:00:00.000Z	2025-06-28T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1600, "totalPrice": 1600, "description": "Driveway"}]	recycled asphalt, skid loader, roller	20% down payment due at signing and remainder due by cash or check upon project completion	1600	2025-06-21 20:33:33.999+00	pending	{"projectOverview":"Wissel Trucking, Inc. is  pleased to present this project estimate for your driveway repair. Our solution will address the existing water hole and restore the driveway's integrity and appearance, enhancing your property's curb appeal and functionality.","scopeOfWork":["Clear the existing driveway area (approximately 125'x10') of all grass and weeds, and haul away debris.","Address the existing water hole to ensure proper drainage and a level surface.","Provide, install, and compact approximately 3 inches of recycled asphalt over the entire driveway surface using a skid loader and roller.","Ensure proper compaction for a durable and long-lasting finish."],"timeline":"The project is expected to take 1 day for completion.","pricing":"The total cost for the driveway repair project is $1600. This pricing includes all labor, materials (recycled asphalt), equipment (skid loader, roller), and disposal fees. A 20% down payment is due at signing, and the remaining balance is payable by cash or check upon project completion."}	7db369b9-1144-4395-931d-abf2b3b4a4ea	4f95ebf0-8d36-4bb6-8013-50364223b382	2025-06-21	residential
09f677c9-59d6-4d5b-b214-62c8c729e9bf	Backyard Grading	Grading backyard after pool removal	Getting backyard ready for grass seed after pool is removed	Remove sand and landscape rock from pool and deck area of backyard. Haul off and dispose of materials. Deliver and grade 1 load of topsoil in back yard. grade to match existing yard	1900	2025-06-24T05:00:00.000Z	2025-06-25T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1900, "totalPrice": 1900, "description": "Yard Grading"}]	Skid loader, dump truck, topsoil	Customer to remove fence to allow a minimum of 7' wide access to back yard.  No ground protection mats included.  Grass seed and landscape restoration is not included. Payment due in full upon project completion 	1900	2025-06-21 20:40:03.92+00	pending	{"projectOverview":"Wissel Trucking, Inc. is  pleased to present this project estimate for your backyard grading needs. Following the removal of your pool, our grading service will prepare your yard for successful grass seeding, eliminating the existing sand and rock and ensuring a smooth, level surface for a beautiful lawn.","scopeOfWork":["Remove all remaining sand and landscape rock from the former pool and deck area within your backyard.","Haul away and properly dispose of all removed materials.","Deliver and grade one (1) load of high-quality topsoil in your backyard to achieve the desired grade.","Grade the topsoil to seamlessly match the existing yard levels, ensuring proper drainage and a smooth transition."],"timeline":"This project is expected to take 1 day to complete.","pricing":"The total cost for this project is $1900. This price is all-inclusive for the scope of work outlined above and is payable in full upon project completion. Please note that this estimate assumes a minimum of 7' wide access to the backyard is available with the removal of any existing fencing completed by owner, and that ground protection mats are not included. Grass seed and any additional landscape restoration beyond the grading service are not included."}	7db369b9-1144-4395-931d-abf2b3b4a4ea	e793b017-12e4-4d7a-a9fc-30b57e84ff01	2025-06-21	residential
f4f20199-58f1-4fcb-8fa4-07e3379faae7	Yard Grading	Regrading front and side yard for positive drainage	providing positive drainage to keep water away from house	Deliver 2 tandem loads of topsoil. Grade topsoil around front and side yards to create positive drainage away from house.  grade remaining topsoil in backyard to level it out	1900	2025-06-27T05:00:00.000Z	2025-06-27T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1900, "totalPrice": 1900, "description": "Yard Grading"}]	Topsoil, Skid loader	No grass seed or landscape restoration included. Payment due in full upon project completion 	1900	2025-06-21 20:46:18.933+00	pending	{"projectOverview":"Wissel Trucking, Inc. is pleased to present this project estimate for your yard regrading. Our solution will address the issue of water pooling around your home's foundation by creating positive drainage, protecting your property from potential water damage.","scopeOfWork":["Deliver two tandem loads of topsoil to your property.","Grade topsoil around the front and side yards to establish positive drainage away from the house foundation.","Grade the remaining topsoil in the backyard to level the area.","Operate a skid loader to ensure proper grading and soil distribution."],"timeline":"This project is expected to be completed within one day.","pricing":"The total cost for this yard regrading project is $1900. This price includes all labor and materials, specifically topsoil and skid loader usage. Please note that this estimate does not include grass seed or landscape restoration. Payment is due in full upon project completion."}	7db369b9-1144-4395-931d-abf2b3b4a4ea	bb56f831-4c93-47f1-843b-d82e4104fc8f	2025-06-21	residential
1ac7ed29-9158-43cf-a236-e58e96267c8a	Yard Grading	Grading side yard along foundation	Brining up dirt along foundation for positive drainage	Provide screened topsoil to build up along north side of house from rock wall to rock wall about 4' out from house. Bring up dirt grade about 1 brick on house foundation.  Spread and grade topsoil with skid loader	1000	2025-06-27T05:00:00.000Z	2025-06-28T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Grading"}]	screened topsoil, skid loader	no seeding or landscape restoration included. Payment due in full upon project completion 	1000	2025-06-22 19:57:19.808+00	pending	{"projectOverview":"Wissel Trucking, Inc. is pleased to present this project estimate for grading the side yard along your foundation. Our solution will effectively address water drainage issues by building up the soil grade and promoting positive drainage away from your home's foundation, thus protecting your property from potential water damage.","scopeOfWork":["Supply and deliver screened topsoil to the north side of the house, spanning from rock wall to rock wall and extending approximately 4 feet outwards from the house.","Increase the soil grade along the foundation by approximately one brick height.","Spread and grade the delivered topsoil using a skid loader to ensure a smooth and even surface that facilitates proper water runoff.","Final grade to ensure positive drainage away from the foundation"],"timeline":"The project is expected to take 1 day  for completion.","pricing":"The total cost for the project is $1000. This pricing includes all labor and materials associated with the grading services as outlined in the scope of work. Please note that seeding or landscape restoration is not included. Payment is due in full upon project completion."}	7db369b9-1144-4395-931d-abf2b3b4a4ea	09f84dfa-884a-4050-8235-01ac5bf87ac5	2025-06-22	residential
4bd7181e-ad44-4f00-919e-c36f0c1cd554	60 quiet springs 30x60 & 11x30 tie in 	30x60 concrete shop pad install	install of pad for future shop build 	will pour slab to support a 30x60 metal shop that customer has on order 	23300	2025-07-08T05:00:00.000Z	2025-07-10T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 19300, "totalPrice": 19300, "description": "30x60 concrete 5.5 inches thick with main beam and 16-18 inch footers "}, {"id": 2, "quantity": 1, "unitPrice": 4000, "totalPrice": 4000, "description": "11x30 concrete to connect driveway to shop front "}, {"id": 3, "quantity": 32, "unitPrice": 110, "totalPrice": 3520, "description": "32 loads of pad dirt "}, {"id": 4, "quantity": 1, "unitPrice": 1500, "totalPrice": 1500, "description": "machine and time to install pad "}]	concrete , rebar , forum boards etc 	50% of job due before start date the remaining due by end of the day of the concrete is poured 	28320	2025-06-27 15:00:53.588+00	pending	{"projectOverview":"We are pleased to present this project estimate for the concrete pad installation at 60 Quiet Springs. This project will provide a solid and reliable foundation for your future 30x60 metal shop, addressing your need for a stable and level surface that meets the specific load-bearing requirements of your building.","scopeOfWork":["Prepare the site for concrete placement, including excavation and grading to ensure proper drainage and a level surface.","Install necessary formwork to define the perimeter of the 30x60 concrete pad.","Reinforce the concrete pad with rebar to enhance its structural integrity and load-bearing capacity.","Pour and finish the concrete pad to a smooth, level surface that meets industry standards and your specific requirements.","Tie in a separate 11x30 pad to the main structure, ensuring a seamless and structurally sound connection.","Remove formwork and perform initial cleanup of the project site."],"timeline":"The project is expected to take 1 week (2 days) for completion, weather permitting.","pricing":"The total cost for the project is $28,320. This pricing includes all labor, materials (concrete, rebar, form boards, etc.), and equipment necessary to complete the project as described. A deposit of 50% of the total cost is due before the start date, with the remaining balance due by the end of the day that the concrete is poured."}	d194c33a-5679-4dcb-b22c-fac98cfec3cf	3612ec74-1141-4ceb-9a36-de675560fddd	2025-06-27	residential
73ca6a40-22b7-4091-b728-02a2109d57da	Conners fence line mulching project	mulching fence line 	mulching unwanted growth for future fence and shop pad 	removed unwanted brush 	1400	2025-07-10T05:00:00.000Z	2025-07-15T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1400, "totalPrice": 1400, "description": "mulching day rate min "}]	100hp skid steer with mulcher 	please make checks payable to Prime Time Land Services LLC. If paying by credit card a 3% fee will be applied for processing fee .	1400	2025-07-01 22:10:26.4+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for the Conners fence line mulching project. Our solution will effectively clear the unwanted growth along your fence line, preparing the area for the future fence and shop pad. This will eliminate existing vegetation and prevent regrowth, ensuring a clean and stable base for your upcoming construction.",\n  "scopeOfWork": "- Removal of all unwanted brush and vegetation along the designated fence line area.\\n- Mulching of the removed brush using a 100hp skid steer with a mulcher attachment.\\n- Even distribution of mulch to create a uniform layer, suppressing future weed growth and erosion.\\n- Clearing and cleaning of the work area upon completion.",\n  "timeline": "The project is expected to take 1 week (5 days) for completion.",\n  "pricing": "The total cost for the Conners fence line mulching project is $1400. This pricing is all-inclusive with no hidden fees. Please make checks payable to Prime Time Land Services LLC. If paying by credit card, a 3% processing fee will be applied."\n}\n```	d194c33a-5679-4dcb-b22c-fac98cfec3cf	a2d48cbc-d085-4137-9ac9-0e2096186f62	\N	residential
afb48375-69ba-41a3-8201-2c70fa3eb93a	banks #150 quite springs trail dirt bid 	raising existing backyard to desirable level	fixing non compacted area bring to better level and apply soil for grass to grow 	bring in dirt 	8950	2025-07-15T05:00:00.000Z	2025-07-18T05:00:00.000Z	[{"id": 1, "quantity": 40, "unitPrice": 110, "totalPrice": 4400, "description": "select fill 60/40"}, {"id": 2, "quantity": 15, "unitPrice": 130, "totalPrice": 1950, "description": "top soil"}, {"id": 3, "quantity": 2, "unitPrice": 1300, "totalPrice": 2600, "description": "machine and operator per day "}]	100hp skid steer 	please make checks payable to Prime Time Land Services LLC.\nIf paying by credit card a 3% processing fee will be added to total 	8950	2025-07-01 22:23:18.577+00	pending	{"projectOverview":"We are pleased to present this project estimate for raising your existing backyard at 150 Quite Springs Trail to the desired level. This solution will address the non-compacted area in your backyard, bringing it to a better level and preparing for healthy grass growth. Our approach involves strategically bringing in and leveling dirt to ensure a solid and stable base for your lawn.","scopeOfWork":["Assessment of the existing backyard grade and identification of non-compacted areas.","Import and placement of necessary dirt to raise the backyard to the desired level.","Compaction and leveling of the newly added dirt to ensure a stable and even surface.","Final grading to prepare the area for grass seeding or sod installation (grass not included)."],"timeline":"The project is expected to take 3 days (approximately 1 week) for completion.","pricing":"The total cost for the project is $8950. This pricing includes all labor, equipment (including the 100hp skid steer), and materials necessary to complete the scope of work as described above. Please note that checks should be made payable to Prime Time Land Services LLC. If paying by credit card, a 3% processing fee will be added to the total."}	d194c33a-5679-4dcb-b22c-fac98cfec3cf	e05439e8-1d83-4a4e-910b-33376625a2b1	2025-07-01	residential
aa4031ca-0673-41a3-9409-d6b22cd484e8	Julia house pad install	building house pad 	installing house pad for new construction home 	build house pad to builder specs 	10720	2025-08-04T05:00:00.000Z	2025-08-05T05:00:00.000Z	[{"id": 1, "quantity": 64, "unitPrice": 130, "totalPrice": 8320, "description": "tested 60/40 pad dirt "}, {"id": 2, "quantity": 1, "unitPrice": 2400, "totalPrice": 2400, "description": "machine and labor "}]	tested correct pad dirt , skid steer , dump trucks 	customer is responsible for compaction testing . 	10720	2025-07-04 21:45:15.961+00	pending	```json\n{\n  "projectOverview": "We are pleased to provide this project estimate for the installation of a house pad at the Julia residence. This project is crucial for providing a stable and level foundation for your new home construction, ensuring the long-term structural integrity of your property.",\n  "scopeOfWork": "- Site preparation and clearing as necessary to prepare for pad installation.\\n- Delivery and placement of tested and approved pad dirt, meeting specified compaction requirements.\\n- Grading and leveling of the house pad according to builder specifications.\\n- Utilization of skid steer and dump trucks for efficient material handling and placement.\\n- Ensuring the house pad dimensions and elevation adhere strictly to the provided plans and specifications.",\n  "timeline": "The project is expected to take 1 day (approximately 1 week accounting for weather or unforeseen delays) for completion.",\n  "pricing": "The total cost for the Julia house pad installation is $10,720. This price includes all labor, materials (tested correct pad dirt), and equipment (skid steer, dump trucks) necessary for the completion of the scope of work as outlined above. Please note that the customer is responsible for compaction testing, which is not included in this estimate."\n}\n```	d194c33a-5679-4dcb-b22c-fac98cfec3cf	966b3b83-0c51-4147-b2a5-4d8774d206e0	\N	residential
801f204d-2ba0-4cd9-a375-0b0fa6e5d147	Hole Fill In	Fill in hole in backyard from pool excavation	Filling in hole to create level backyard	Use excavated dirt beside house to fill in hole in backyard. Bring in up to 4 more loads of clay to fill hole back up to grade. bring in one load of topsoil to finish grading area	3000	2025-07-09T05:00:00.000Z	2025-07-09T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "Fill in excavated hole"}]	skid loader, dump truck, clay dirt, topsoil	no seeding is included. rebuilding retaining wall is not included.  payment due in full at project completion by cash or check	3000	2025-07-05 15:19:26.33+00	pending	{"projectOverview":"Wissel Trucking, Inc pleased to present this project estimate at 115 Aspen Ct for filling in the excavated pool area in your backyard. Our solution will effectively address the uneven terrain, transforming it into a level and usable space, enhancing the aesthetic appeal and functionality of your property.","scopeOfWork":["Utilize the existing excavated dirt located beside the house to begin filling the hole in the backyard.","Transport up to four (4) additional loads of clay dirt to the site using a dump truck.","Fill the hole with clay dirt, bringing the area back up to the desired grade.","Deliver and spread one (1) load of topsoil to finalize grading in the affected area.","Utilize a skid loader for efficient material handling and distribution."],"timeline":"The project is expected to take approximately 1 day for completion, subject to weather conditions and material availability.","pricing":"The total cost for the project is $3000. This pricing is all-inclusive of labor, materials (clay dirt and topsoil), and equipment (skid loader and dump truck). Please note that seeding and rebuilding the retaining wall are not included in this estimate. Payment is due in full at project completion, payable by cash or check."}	7db369b9-1144-4395-931d-abf2b3b4a4ea	6c62f62b-e8ba-4deb-ac81-0dabae3a2cb2	2025-07-05	residential
31a40a5f-ae5b-4b7a-a0cc-c8e3775b7c5c	New Driveway	New driveway	Install new rock driveway at property	New driveway to be about 55' long by 18' wide. Dig out 3-4" of existing material to make new driveway area. Cut into slopes on sides to widen drive and make it mowable. Haul off excavated materials. Provide and install 3-4" of CA-6 white rock for new driveway. Compact rock with vibratory roller	2000	2025-07-22T05:00:00.000Z	2025-07-22T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "New Driveway"}]	skid loader, dump truck, CA-6 white rock	No seeding or landscape restoration included. Payment due in full by cash or check upon project completion 	2000	2025-07-10 02:52:01.643+00	pending	{"projectOverview":"Wissel Trucking, Inc. is  pleased to present this project estimate at 104 E Jefferson St for the installation of a new driveway at your residential property. This new driveway will enhance the accessibility and aesthetic appeal of your property, providing a durable and visually pleasing solution to meet your needs.","scopeOfWork":["Excavate approximately 3-4 inches of existing material from the designated driveway area (approximately 55' long by 18' wide).","Cut into adjacent slopes to widen the driveway and create mowable edges.","Haul away all excavated materials from the site.","Provide and install 3-4 inches of CA-6 white rock for the new driveway surface.","Compact the newly installed rock using a vibratory roller to ensure a stable and even surface."],"timeline":"The project is expected to be completed within the same day.","pricing":"The total cost for the project is $2000. This pricing includes all labor, materials (skid loader, dump truck, and CA-6 white rock), and equipment necessary to complete the project as described. Please note that payment is due in full by cash or check upon project completion. This estimate does not include seeding or landscape restoration."}	7db369b9-1144-4395-931d-abf2b3b4a4ea	b4be0b4a-4be0-4d9e-a8ae-116442248336	2025-07-10	residential
699266f1-a8cb-4e26-8e2f-5262b25742dc	Yard Grading	Removing and installing new topsoil	Provide quality topsoil to grow grass	Remove about 3" of existing grass and dirt from entire property (7,700 SF approx). Haul off all excess materials. fill along edge of new driveway. Provide and install 3" of shredded/screened topsoil over entire property. Grade backyard with laser to help waterflow	11220	2025-08-19T05:00:00.000Z	2025-08-22T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 11220, "totalPrice": 11220, "description": "Remove and replace topsoil"}]	Skid loader, excavator, dump truck, topsoil	grass seeding is not included. cant not guarantee backyard can be made 100% dry in rainfall.  Care will be taken to not damage buried downspouts 	11220	2025-07-28 12:23:23.975+00	pending	```json\n{\n  "projectOverview": "We are pleased to present this project estimate for your yard grading project.  Currently, your property lacks the quality topsoil necessary for healthy grass growth. Our solution will address this by removing the existing subpar soil, installing premium screened topsoil, and expertly grading your yard to promote proper water drainage, resulting in a lush, vibrant lawn.",\n  "scopeOfWork": "- Removal of approximately 3\\" of existing grass and topsoil from your entire 7,700 square foot property.\\n- Safe and efficient hauling away of all excess materials.\\n- Filling along the edge of your new driveway with the excavated material.\\n- Delivery and installation of 3\\" of high-quality shredded and screened topsoil across the entire property.\\n- Precise laser grading of your backyard to optimize water flow and prevent waterlogging.\\n- Careful operation to minimize the risk of damaging underground downspouts.",\n  "timeline": "The project is expected to be completed within 3 days (1 week).",\n  "pricing": "The total cost for this project is $11,220.  This all-inclusive price covers all labor, materials (including skid loader, excavator, dump truck, and topsoil), and equipment usage. There are no hidden fees."\n}\n```\n	7db369b9-1144-4395-931d-abf2b3b4a4ea	b4be0b4a-4be0-4d9e-a8ae-116442248336	\N	comprehensive
0335d8e5-c628-458d-aba2-1aa5513a0401	Shed Pad	Shed Pad	Install Level rock pard for garden shed	remove existing rock and install in alley hole\nnew pad to be about 15'x25' in size\nStrip sod as needed for new pad and grade on site\nRemove and dispose of existing concrete pad\nintall weed fabric under area\ninstall and Compact CA-6 white rock for pad area level within an inch for shed foot print	1700	2025-07-28T05:00:00.000Z	2025-07-28T05:00:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1700, "totalPrice": 1700, "description": "shed pad"}]	skid loader, roller, dump truck, weed fabric, CA-6	moving of shed not included, landscape and yard restoration not included, payment due in full upon project completion 	1700	2025-07-20 15:59:44.413+00	pending	```json\n{\n  "projectOverview": "This project estimate details the construction of a new, level shed pad for your garden shed.  We understand the frustration of an uneven shed base and the potential damage this can cause to your structure. Our solution will provide a stable, level foundation for your shed, ensuring its longevity and protecting it from settling and damage. This will enhance the overall appearance and functionality of your shed and property.",\n  "scopeOfWork": "- Removal of existing concrete pad and disposal of materials.\\n- Stripping of sod and grading of the site as needed for proper pad installation.\\n- Installation of weed fabric to prevent weed growth under the new pad.\\n- Installation of approximately 375 square feet (15' x 25') of CA-6 white rock, compacted to ensure a level surface within one inch of level across the shed footprint. \\n- All necessary equipment including skid steer, roller, and dump truck will be used to complete the project to the highest standards.",\n  "timeline": "The project is estimated to take 0 days for completion.  This timeline is contingent upon favorable weather conditions and site accessibility.",\n  "pricing": "The total cost for this project is $1700. This price is all-inclusive and covers all labor, materials (including CA-6 white rock, weed fabric, and equipment rental), and disposal fees. Payment is due in full upon project completion. Please note that the moving of the shed, any landscape restoration beyond the immediate shed pad area, and yard restoration are not included in this estimate."\n}\n```\n	7db369b9-1144-4395-931d-abf2b3b4a4ea	b4be0b4a-4be0-4d9e-a8ae-116442248336	\N	comprehensive
32571bb9-6561-483a-aeba-0a695f96aa45	here	\N	\N	\N	\N	\N	\N	\N	\N		234	2025-07-23 17:12:43.851+00	pending	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	8d7d81a4-0b07-4493-a840-acf0e56f4c4b	\N	\N
8cb11925-1e53-4199-95a5-1af6d2a1c217	tycoon	\N	\N	\N	\N	\N	\N	\N	\N		3000	2025-07-23 17:13:18.155+00	pending	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	150b6138-0a0d-4d3e-bc5a-da191f36f322	\N	\N
9ba48601-708b-4a33-bd1e-533184ef2096	chin	\N	\N	\N	\N	\N	\N	\N	\N		3000	2025-07-23 17:18:05.228+00	pending	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	8d7d81a4-0b07-4493-a840-acf0e56f4c4b	\N	\N
001a36ad-2fa0-4a53-93bf-bc19ac51c304	xin	\N	\N	\N	\N	\N	\N	\N	\N		333	2025-07-23 17:25:16.647+00	pending	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e056cef7-d455-4f49-a63d-d446218db39b	\N	\N
98e2ee0f-5e01-46a8-bada-964b28ce6ea3	mix	\N	\N	\N	\N	\N	\N	\N	\N		3000	2025-07-23 17:26:55.548+00	pending	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	8d7d81a4-0b07-4493-a840-acf0e56f4c4b	\N	\N
98af0c0e-50b3-4a0c-b9e5-e2e070d354c7	shinn	exacavation	drainage system installation	drainage system installation	1	2025-07-09T18:30:00.000Z	2025-07-16T18:30:00.000Z	[{"id": 1, "quantity": 1, "unitPrice": 1, "totalPrice": 1, "description": "stone"}]	efwss	wefefefdw	1	2025-07-23 17:31:22.377+00	pending	```json\n{\n  "projectOverview": "This project estimate outlines the plan for installing a new drainage system at your property.  We understand the challenges associated with inadequate drainage, such as water damage to your property and potential foundation issues. Our proposed solution will effectively address these concerns, creating a more stable and protected environment for your property. This comprehensive installation will provide long-term protection and peace of mind.",\n  "scopeOfWork": "- Site assessment and planning for optimal drainage system placement.\\n- Excavation of trenches to the required depth and width.\\n- Installation of the drainage system using high-quality efwss materials.\\n- Backfilling and compaction of trenches to ensure stability.\\n- Final grading and cleanup of the site.",\n  "timeline": "The project is expected to take 1 week (7 days) for completion.",\n  "pricing": "The total cost for this project, including all materials (efwss) and labor, is $1. This pricing is all-inclusive and transparent with no hidden fees."\n}\n```\n	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e056cef7-d455-4f49-a63d-d446218db39b	\N	detailed
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoices (id, invoice_number, issue_date, due_date, invoice_total_amount, line_items, invoice_summary, remit_payment, estimate_id, additional_notes, status, created_at, updated_at, project_id, user_id, client_id) FROM stdin;
7207b4df-0f3a-4574-9b5a-3673a3d467fa	U8G4T	2025-04-01 16:41:06.085+00	2025-04-11 18:30:00+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes"}]		{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-01 16:45:30.073+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	\N	\N
cc64493a-9de7-4bba-a6a0-f9a0623ed5cc	MJ9BR	2025-04-01 16:41:06.085+00	2025-04-11 18:30:00+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes"}]		{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-01 16:45:41.144+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	\N	\N
6620b6e4-7721-421a-a97f-7d9ec6d51dba	7SC8E	2025-04-01 18:12:34.913+00	2025-04-03 18:30:00+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes and Gravel"}]		{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-01 18:13:40.19+00	\N	64dbcba2-2430-4e08-8527-c68c96b295a8	\N	\N
3d83de59-a023-4fde-83f7-92df5d8fda42	ZSX1X	2025-04-01 18:15:50.463+00	2025-04-03 18:30:00+00	3000.00	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "Shoes and Excavator"}]		{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-01 18:16:21.985+00	2025-04-02 11:20:34.764192+00	bbe719db-59a6-4072-a0fe-81cc0b16bd84		\N
ae66e65c-25e2-424a-bbbf-0f78250dc9e1	SQ295	2025-04-03 10:16:50.472+00	2025-04-09 18:30:00+00	3000.00	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "New Haven"}]		{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-03 10:17:05.244+00	\N	c517aa79-8476-4b7b-970c-10acc1468126	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
b87cbbb9-e9ee-4508-a6b3-ec10565df2fd	KO9ZQ	2025-04-05 19:35:59.527+00	2025-04-10 18:30:00+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes and Gravel"}]		{"taxId": "TXN8263", "accountName": "code community", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-05 19:36:50.021+00	\N	d670a38f-a21b-4757-85f6-e2c6b6c58780	961af7eb-1a61-47ac-9fd4-e8174218a32f	\N
4cd78f3c-8528-40b3-bc3a-8397a8c10848	CNVHY	2025-04-05 19:35:59.527+00	2025-04-10 18:30:00+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes and Gravel"}]		{"taxId": "TXN8263", "accountName": "code community", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-05 19:37:09.33+00	\N	d670a38f-a21b-4757-85f6-e2c6b6c58780	961af7eb-1a61-47ac-9fd4-e8174218a32f	\N
53f615fc-9c6f-49dd-a404-e2ff19ff0452	HUKE0	2025-04-05 19:40:24.2+00	2025-04-06 18:30:00+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Hiroshima"}]		{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-05 19:40:56.49+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
11d08966-6ba1-4b01-bdf7-efdf0a9d2193	SKQ5C	2025-04-15 17:34:59.851+00	2025-04-16 17:34:59.851+00	200.00	[{"id": 1, "quantity": 1, "unitPrice": 200, "totalPrice": 200, "description": "shoes"}]	Installing a drove	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-15 17:39:43.774+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
c0f02320-9e5c-455e-a75d-902c2de92024	GMK1E	2025-04-15 17:40:02.698+00	2025-04-15 17:40:02.698+00	3000.00	[{"id": 1, "quantity": 3, "unitPrice": 1000, "totalPrice": 3000, "description": "wonder"}]	drainage system	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-15 17:42:11.879+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
3daf4fc0-3e04-477a-a32b-ae826193c250	JZBSTOYF	2025-04-16 11:14:04.91+00	2025-04-16 11:14:04.91+00	0.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	draft	2025-04-16 11:14:07.663+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
4e348a88-232e-4986-94a6-3f18f8c9130e	8739GQBN	2025-04-16 11:14:20.034+00	2025-04-16 11:14:20.034+00	3000.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": "shoes"}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	draft	2025-04-16 11:14:30.665+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
48b1f8c4-47b8-42a6-aad1-95cdd82d405c	D5JE53DS	2025-04-16 18:30:00+00	2025-04-19 18:30:00+00	200.00	[{"id": 1, "quantity": 1, "unitPrice": 200, "totalPrice": 200, "description": "Shoes and Gravel"}]	Trench System	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	draft	2025-04-16 11:15:36.076+00	\N	c517aa79-8476-4b7b-970c-10acc1468126	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
e13f11f8-af6a-4876-822a-74c57c5d1a83	1HF9MTU5	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of Houses	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	draft	2025-04-16 11:16:15.766+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
e38fbacc-d1bf-450d-a078-0fb4a40847e6	TS5ERXLW	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of Housess	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	draft	2025-04-16 11:17:23.489+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
f8ea70f9-b2fa-4fb4-8d4a-3929cc92dc7d	4C4D5	2025-04-03 10:00:09.409+00	2025-04-09 18:30:00+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoes"}]		{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	paid	2025-04-03 10:00:45.153+00	2025-04-18 11:57:18.544762+00	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
72995e40-dce0-4075-adf7-2e1a61afe212	NR69MZQI	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of Housesss	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	draft	2025-04-16 11:19:31.511+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N
4c16877a-08c2-4b04-9acc-191f18437b75	53J1BVCD	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of Housess	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-16 11:27:30.587+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
c1be23a6-212f-4082-b33b-79fc11749841	YA9TNVVZ	2025-04-16 10:45:06.489+00	2025-04-16 10:45:06.489+00	0.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	draft	2025-04-16 11:13:52.019+00	2025-04-16 11:28:33.675721+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327
1a7b6571-4f3a-4705-9407-af0e69ff1143	6T8XZB1P	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of House	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-16 11:29:27.949+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
d2f3ca91-d571-4927-b945-0922721e88b7	4LQWG2DM	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of Housess	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-16 11:31:49.87+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
5220bdfe-1c49-4f49-8ffd-024fae949878	8DW2ZEHX	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of Houseddd	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-16 11:35:02.47+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
53230a13-77bb-4c37-b2c4-7dc304c13cf9	P0Y9CEVB	2025-04-16 11:36:32.096+00	2025-04-16 11:36:32.096+00	0.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	draft	2025-04-16 11:36:41.857+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	306a3b82-d6e7-4d95-92a7-3975d54c7c18
8d3fc783-ced9-4065-965e-7266ffb565ee	OD4W704W	2025-04-16 11:36:47.97+00	2025-04-16 11:36:47.97+00	0.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	draft	2025-04-16 11:36:52.097+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	df0c7d05-c664-41ca-a371-7a4645c7657a
d10508a3-6d21-42f2-abec-d1f128fbc46a	6DAEWJVI	2025-04-16 12:01:07.262+00	2025-04-16 12:01:07.262+00	0.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	draft	2025-04-16 12:01:12.565+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	67e56aaa-0e04-4d61-8834-61e4c80f3f99
1d950cfd-ae52-4537-b09c-7174342774cd	1WMS80N6	2025-04-16 12:30:23.638+00	2025-04-16 12:30:23.638+00	2220.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]	orangearmy	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-16 12:40:59.735+00	2025-04-18 11:59:24.840011+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	67e56aaa-0e04-4d61-8834-61e4c80f3f99
ce8b1ba2-5f73-41da-8daf-6f7ca8559167	XM98V9MS	2025-04-16 12:30:23.638+00	2025-04-16 12:30:23.638+00	2220.00	[{"id": 1, "quantity": 1, "unitPrice": 20, "totalPrice": 20, "description": "shoes"}]	orange	{"taxId": "TCABEUEL", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-16 12:30:42.115+00	2025-04-19 18:23:20.162524+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327
714cd220-d7a4-4560-84ff-eee14456ecb4	ZM082KVB	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of Housess	{"taxId": "TCABEUEL", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-16 11:20:29.112+00	2025-04-19 18:54:08.206919+00	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
6b57a684-c23a-4cdd-8e17-16fda2d41a85	SU250QMR	2025-04-16 11:35:18.138+00	2025-04-16 11:35:18.138+00	222.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": "fbfb f"}]		{"taxId": "TCABEUELEW", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "826376365"}	\N	\N	draft	2025-04-16 11:35:28.595+00	2025-04-18 13:10:09.950473+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
b9994d05-d154-4c3c-a7ef-8d5a06e5cc9c	8ZGRFDCU	2025-04-16 12:30:23.638+00	2025-04-16 12:30:23.638+00	22202.00	[{"id": 1, "quantity": 200, "unitPrice": 1, "totalPrice": 200, "description": "eewwve"}]	orange	{"taxId": "TCABEUEL", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-16 12:40:44.794+00	2025-04-19 18:40:01.975241+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	df0c7d05-c664-41ca-a371-7a4645c7657a
540565d9-f981-46ac-ae4c-2d473b26b3c7	04UHN0JB	2025-04-16 12:29:06.314+00	2025-04-16 12:29:06.314+00	3000.00	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "shoes"}]	sdvdsvsdv	{"taxId": "TCABEUEL", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-16 12:29:15.126+00	2025-04-19 18:41:41.922327+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
7b795cc1-8ddd-4566-a7e9-feeba7d3e62e	6G77W002	2025-04-16 12:30:23.638+00	2025-04-16 12:30:23.638+00	2220.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]	orangearmy era	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-16 12:42:00.97+00	2025-04-16 13:57:04.813789+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	df0c7d05-c664-41ca-a371-7a4645c7657a
bc74f892-69af-4acc-a065-7e85d54ca469	TX6NDW2U	2025-04-16 12:30:23.638+00	2025-04-16 12:30:23.638+00	2220.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]	orangearmy era	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-16 12:41:16.011+00	2025-04-17 11:04:15.768988+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	306a3b82-d6e7-4d95-92a7-3975d54c7c18
b5201993-5d3c-4e6c-b5a2-ee24740afee5	GMA7PZQ6	2025-04-16 18:30:00+00	2025-04-29 18:30:00+00	3000.00	[{"id": 1, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Gravel"}, {"id": 3, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "New item"}]	Installing a trench to divert water away from the house	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-18 12:28:44.89+00	\N	d199c128-0dc4-4024-af95-bf835ed793ea	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327
8e1551fa-f351-4197-b938-40eb50d23dd3	8SHCUW15	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	ssRemoving Mines infront of House	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-16 11:33:23.455+00	2025-04-16 13:39:51.511357+00	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
d5eb7f37-a686-4d9d-95de-8c2cd90eb150	FNA5QIKR	2025-04-16 12:30:23.638+00	2025-04-16 12:30:23.638+00	2220.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]	orangearmy erasss	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-16 12:44:45.522+00	2025-04-16 13:51:58.364678+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	67e56aaa-0e04-4d61-8834-61e4c80f3f99
7e4d1e0a-a736-4e56-b015-98d925956770	YAU5PDVS	2025-04-16 12:30:23.638+00	2025-04-16 12:30:23.638+00	2220.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]	orangearmy era	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-16 12:41:32.748+00	2025-04-16 13:58:57.357227+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
ba9702ea-5b2e-4c13-8623-564435505c1d	GHNH8S7U	2025-04-18 12:36:18.408+00	2025-04-18 12:36:18.408+00	200.00	[{"id": 1, "quantity": 1, "unitPrice": 200, "totalPrice": 200, "description": "df"}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-18 12:36:59.895+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	150b6138-0a0d-4d3e-bc5a-da191f36f322
59abf199-e0bb-4405-8a7f-c1cbffae43b9	6NYQJGS2	2025-04-16 18:30:00+00	2025-04-29 18:30:00+00	3000.00	[{"id": 1, "quantity": 2, "unitPrice": 1000, "totalPrice": 2000, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Gravel"}, {"id": 3, "quantity": 1, "unitPrice": 0, "totalPrice": 0, "description": "New item"}]	Installing a trench to divert water away from the house	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-18 12:20:09.183+00	2025-04-18 12:23:49.535074+00	d199c128-0dc4-4024-af95-bf835ed793ea	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327
33f7c501-366f-454a-bf7e-7009c0793706	OHT0YQO5	2025-04-18 12:37:20.827+00	2025-04-18 12:37:20.827+00	211.00	[{"id": 1, "quantity": 1, "unitPrice": 200, "totalPrice": 200, "description": "shoes"}]	sa	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-18 12:38:25.002+00	2025-04-18 12:39:46.593145+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	c23efca5-e794-404f-8c32-9c62c7b82e23
4c3e47f7-2539-4b48-964d-e5a0359933f9	F6Q9S082	2025-04-09 18:30:00+00	2025-04-16 18:30:00+00	4000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Shoe and Gloves"}, {"id": 2, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "Gravels"}]	Installing a trench system to divert water away from house	{"taxId": "TCABEUELEW", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-18 18:18:59.257+00	2025-04-18 18:19:31.930674+00	c5201dc5-30bf-4fa4-b395-ae6c01bfa280	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	839b6b01-af69-4d9c-baab-efebe14e67db
dfb2dc34-302f-47a9-a079-0ba5cc601073	JJOR0SZK	2025-04-18 16:35:22.798+00	2025-04-18 16:35:22.798+00	3000.00	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "shoes"}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-18 16:36:03.462+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	af7ea608-6ab7-4eb5-a377-e191eee7c8f0
6b52e3cc-e2c9-4b1e-a14a-5fb702667cf7	16TJVJ1Q	2025-04-18 13:11:16.733+00	2025-04-18 13:11:16.733+00	0.00	[{"id": 1, "quantity": 0, "unitPrice": 0, "totalPrice": 0, "description": ""}]	baaaa ssss	{"taxId": "TCABEUELEW", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "826376365"}	\N	\N	unpaid	2025-04-18 13:11:29.964+00	2025-04-18 13:11:48.278334+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	df0c7d05-c664-41ca-a371-7a4645c7657a
d111ec13-08bf-4897-850e-2ea5c08c75b2	29PVALLS	2025-04-16 18:30:00+00	2025-04-24 18:30:00+00	3500.00	[{"id": 1, "quantity": 2, "unitPrice": 1000, "totalPrice": 2000, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Gravel"}, {"id": 3, "quantity": 1, "unitPrice": 500, "totalPrice": 500, "description": "New item"}]	Installing a trench to divert water away from the housesssssss bbreajk area	{"taxId": "TCABEUEL", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-18 12:56:47.849+00	2025-04-19 18:40:36.995104+00	d199c128-0dc4-4024-af95-bf835ed793ea	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327
b9b801fd-5216-4115-bad9-8445b7f76ebd	OEPBRHRN	2025-04-17 18:30:00+00	2025-04-19 18:30:00+00	4000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "shoes"}, {"id": 2, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "gravel"}]	installing a trench to divert water away from the house	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-18 16:35:14.472+00	\N	a0ef366b-dec9-45d2-aa5d-617f95ffe12c	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	68d2d543-f52a-4130-a457-5471bf8a2856
4d86aaeb-d5b8-43d7-82be-5ff5ad4181de	8XPE2S1D	2025-04-18 13:12:30.344+00	2025-04-18 13:12:30.344+00	2000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "shoes and gravel"}]	orange army	{"taxId": "TCABEUEL", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-18 13:12:35.313+00	2025-04-19 18:37:08.430689+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
fea7c191-5594-4247-9e94-ebb9dd96ee3b	E7I7UF9C	2025-04-22 05:00:00+00	2025-04-30 05:00:00+00	10000.00	[{"id": 1, "quantity": 1, "unitPrice": 5000, "totalPrice": 5000, "description": "Excavator"}, {"id": 2, "quantity": 1, "unitPrice": 5000, "totalPrice": 5000, "description": "Gravel"}]	Need to construct a road with minimal time with good equipment	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-19 15:30:11.681+00	2025-04-19 15:30:51.000522+00	01b25541-a7fe-4a9b-8f1a-c3301aaae32c	d9432cc7-89b9-45ab-9ffc-365a86939107	e0abaf61-3f57-4009-b168-b07db5e48d74
bc6e9879-5911-44c7-8f02-4001dccb6ae4	ULPVG2K2	2025-04-16 12:24:16.266+00	2025-04-16 12:24:16.266+00	3000.00	[{"id": 1, "quantity": 1, "unitPrice": 2000, "totalPrice": 2000, "description": "shoes and gravel"}]	here is the summary	{"taxId": "TCABEUEL", "accountName": "tarun kumar", "accountNumber": "274HGE73WUI", "routingNumber": "8263763653"}	\N	\N	unpaid	2025-04-16 12:24:20.782+00	2025-04-19 18:52:25.202847+00	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
39e88e4e-3093-46d8-a329-ecf79fd1ffda	JDFU6U4Y	2025-04-09 18:30:00+00	2025-04-15 18:30:00+00	3000.00	[{"id": 1, "quantity": 1, "unitPrice": 3000, "totalPrice": 3000, "description": "shoes"}]	installing a trench system to divert water away from the house	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-19 18:59:43.449+00	\N	d0e1ae4b-c320-492c-bdee-d6488b6a01ed	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	19520e84-fe1a-4742-8bf1-0586bcf6f0c0
2a903bd3-fc8e-4ad1-a5db-ff4884be0c2a	G7BI1YJL	2025-04-15 18:30:00+00	2025-04-16 18:30:00+00	3000.00	[{"id": 1, "quantity": 2000, "unitPrice": 1, "totalPrice": 2000, "description": "Shoes"}, {"id": 2, "quantity": 500, "unitPrice": 2, "totalPrice": 1000, "description": "Gravel"}]	Installing a trench system to divert water away from the house	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-19 19:00:45.377+00	\N	179866c0-792c-4767-a564-a895b0d47534	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e63f515e-2515-4c76-b79a-b639b35e1327
49ffd3ff-74ca-442e-9ecf-410d97b6715c	JW770DES	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of House	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-19 19:02:26.959+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
802a7020-f129-4c5a-9602-5793ea0e6321	QV51MR1V	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of House	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-19 19:05:01.571+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
7ff8dd60-df71-4e40-9d82-d2bd89937bc8	M61YS31R	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of House	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-19 19:09:39.397+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
7dae8756-5056-4609-b715-6af8f4b2f7e9	6JFNV8S0	2025-04-08 18:30:00+00	2025-04-10 18:30:00+00	320.00	[{"id": 1, "quantity": 10, "unitPrice": 20, "totalPrice": 200, "description": "Shoes"}, {"id": 2, "quantity": 1, "unitPrice": 120, "totalPrice": 120, "description": "Gravel"}]	Removing Mines infront of House	{"taxId": "TXN8263", "accountName": "Mohammed Azhar", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-19 19:13:34.222+00	\N	b5312352-a9d4-4d8f-a4de-e3c896e4418a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	54d3809e-869d-4bef-b6ab-3703d6a84897
59f893d1-6efd-467d-bfa2-2ddf6ff9c590	8SR7V99X	2025-04-23 22:00:00+00	2025-04-29 22:00:00+00	1250.00	[{"id": 1, "quantity": 1, "unitPrice": 250, "totalPrice": 250, "description": "Materials"}, {"id": 2, "quantity": 1, "unitPrice": 1000, "totalPrice": 1000, "description": "Work"}]	installing a trench system to divert water	{"taxId": "TXN8263", "accountName": "Robert Dobrilovic", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-04-22 09:41:05.265+00	\N	aef8871f-cafb-48b5-a8ab-6c90c5a0fe63	94ef9a8f-98e7-46ca-ad16-a9bbceef6ca6	5f894019-d57e-47dc-aa3e-3bd0464e9ef1
a117f2d6-9bc8-46ba-8848-798d132aa6a6	R6F07435	2025-04-23 13:16:37.628+00	2025-04-23 13:16:37.628+00	1000.00	[{"id": 1, "quantity": 10, "unitPrice": 100, "totalPrice": 1000, "description": "We sang and danced while working"}]	Installing a drainage solution while singing and dancing and worshipping jarilo	{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-04-23 13:18:19.92+00	\N	\N	4a131143-f973-4f8d-8b4b-83fafedcf9df	3afba4f2-cd52-47f1-b9e6-c05130557a07
6c2b1de8-5931-4a5c-b23a-9e332cfb7ac8	KURSX7Z0	2025-05-06 05:00:00+00	2025-05-13 05:00:00+00	4800.00	[{"id": 1, "quantity": 1, "unitPrice": 3500, "totalPrice": 3500, "description": "Grading Services "}, {"id": 2, "quantity": 1, "unitPrice": 1300, "totalPrice": 1300, "description": "Grass seeding and Straw"}]	We will completyey regrade the entire yard so water properly drains away from the house and towards the wooded edge of the yard.  We will use a laser system to stay on grade abnd maintain the proper slope.  Once the yard is graded properly we will grass seed the entire yard and spead straw on top to keep the seed in place.  when we leave the only thing thge custoer will hgave to do is water the yard.	{"taxId": "TXN8263", "accountName": "Skid Steer Nation", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	draft	2025-05-15 17:57:44.416+00	\N	c76551f9-9e78-4a5b-a09e-b1f475423939	835c094d-bb0a-4ccc-97b0-228210ea817b	44652c5e-c833-422c-bcc1-1b848646d2f6
fb91231a-ee60-4d33-9617-481e8f25311a	0N05FOLS	2025-05-06 05:00:00+00	2025-05-13 05:00:00+00	4800.00	[{"id": 1, "quantity": 1, "unitPrice": 3500, "totalPrice": 3500, "description": "Grading Services "}, {"id": 2, "quantity": 1, "unitPrice": 1300, "totalPrice": 1300, "description": "Grass seeding and Straw"}]	We will completyey regrade the entire yard so water properly drains away from the house and towards the wooded edge of the yard.  We will use a laser system to stay on grade abnd maintain the proper slope.  Once the yard is graded properly we will grass seed the entire yard and spead straw on top to keep the seed in place.  when we leave the only thing thge custoer will hgave to do is water the yard.	{"taxId": "TXN8263", "accountName": "Skid Steer Nation", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-05-19 15:36:45.505+00	\N	c76551f9-9e78-4a5b-a09e-b1f475423939	835c094d-bb0a-4ccc-97b0-228210ea817b	44652c5e-c833-422c-bcc1-1b848646d2f6
20180768-168e-45eb-8436-12eb50f56da5	4GD5GPDQ	2025-05-27 05:00:00+00	2025-05-27 05:00:00+00	3500.00	[{"id": 1, "quantity": 1, "unitPrice": 3500, "totalPrice": 3500, "description": "gravel "}]	grade tge drivewya to remove imperfections and privide a solid base for the =new ca6.  	{"taxId": "TXN8263", "accountName": "Skid Steer Nation", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-05-22 16:08:42.304+00	\N	d6086b2b-1e09-48d3-a9f9-e3f6967d7158	835c094d-bb0a-4ccc-97b0-228210ea817b	1a00e395-fb2d-48f3-a7f5-46754937796e
73661ef4-511b-4d85-9520-1eb6891bea40	ID275Z0U	2025-06-03 05:00:00+00	2025-06-04 05:00:00+00	100.00	[{"id": 1, "quantity": 2, "unitPrice": 50, "totalPrice": 100, "description": "1233"}]	Rake, install & grade gravel	{"taxId": "TXN8263", "accountName": "Daniel Morgan", "accountNumber": "234234234", "routingNumber": "111000025 "}	\N	\N	unpaid	2025-05-30 18:02:58.305+00	\N	3c6d4436-46ee-4f66-9a84-74a2bf999457	71fbf873-af4f-4f51-95f1-153ba64776e3	4c1b10bb-e53f-4ff8-8127-8aeda4d7982d
ba1e9440-d461-43ab-88b8-4d66390465f7	WT8I5RAV	2025-07-23 17:32:07.487+00	2025-07-23 17:32:07.487+00	100.00	[{"id": 1, "quantity": 1, "unitPrice": 100, "totalPrice": 100, "description": "gravel"}]		{"taxId": "TXN274GH", "accountName": "tarun", "accountNumber": "274HGE73WUI", "routingNumber": "123456789"}	\N	\N	unpaid	2025-07-23 17:32:26.703+00	\N	\N	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	156a5db3-4c0d-4716-99f2-5ad8bff6bf65
\.


--
-- Data for Name: jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.jobs (id, user_id, client_id, name, type, description, date, amount, hours, notes, created_at, updated_at) FROM stdin;
15cca3d0-263f-439c-a5d7-b73862957baf	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	839b6b01-af69-4d9c-baab-efebe14e67db	new one	Electrical	hello world	2025-07-22 18:30:00+00	322	22		2025-07-14 18:15:57.590875+00	2025-07-23 13:50:39.391+00
9daa8036-d12d-4767-b05d-cf9677211490	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	c9a6d5ce-d4a3-4e2c-b1bf-750f1c1995b5	pipeline	Plumbing	pipeline fixing	2025-07-22 18:30:00+00	3238	21		2025-07-13 19:15:23.330699+00	2025-07-23 13:50:50.196+00
0e1d3d70-0672-4546-9566-2158614cf9b1	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	839b6b01-af69-4d9c-baab-efebe14e67db	eeer	Electrical	electrical work	2025-07-16 18:30:00+00	3000	33		2025-07-23 17:22:07.79573+00	\N
6da58388-c399-4852-a76c-11a6c4274c7f	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e056cef7-d455-4f49-a63d-d446218db39b	Excavating	Electrical	Excavating 	2025-07-22 18:30:00+00	222	22		2025-07-23 18:14:01.153838+00	2025-07-23 18:14:52.874+00
bb4afe42-2ddf-4486-9329-b5f48306f037	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N	tent	Other	It is good work	2025-06-30 18:30:00+00	2221	22		2025-07-23 12:42:38.157697+00	2025-07-30 14:53:18.432+00
83d0f484-ed43-48da-a3bc-e41c548b03de	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	\N	eett	qwe		2025-07-02 18:30:00+00	12	22		2025-07-30 13:17:12.932884+00	2025-07-30 14:55:13.793+00
d7412273-0d2f-484c-8786-52831c33888f	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	30a2a1c1-4c7d-4854-812b-186659d6087c	FEV			\N	\N	\N		2025-07-30 14:55:49.571869+00	\N
\.


--
-- Data for Name: payment_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payment_info (id, user_id, account_holder_name, account_number, bank_name, branch_code, routing_number, swift_code, tax_id, created_at, updated_at) FROM stdin;
8eb9f509-2ec6-4dec-beb6-7cd10a15b544	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	tarun kumar	274HGE73WUI	ascsa	SBIN028	8263763653		TCABEUEL	2025-04-16 19:04:15.527+00	2025-04-18 18:27:36.314863+00
\.


--
-- Data for Name: pipeline_leads; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pipeline_leads (id, user_id, client_id, stage_id, estimated_value, expected_close_date, notes, created_at, updated_at) FROM stdin;
7d192c99-c333-485a-8fa5-33fcae57f9b1	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e056cef7-d455-4f49-a63d-d446218db39b	b84c0ef7-31df-4a47-96ab-7bdbc9fd155d	32.00	2025-07-01		2025-07-23 17:40:07.400009+00	2025-07-23 17:40:07.400009+00
8b62e250-6c20-4116-a580-26097b1b7149	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	30a2a1c1-4c7d-4854-812b-186659d6087c	b84c0ef7-31df-4a47-96ab-7bdbc9fd155d	34.00	2025-07-23		2025-07-23 17:53:04.434825+00	2025-07-23 17:53:04.434825+00
5a1a6f06-29a4-4103-a44a-4aeba931590a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e056cef7-d455-4f49-a63d-d446218db39b	1aa947d2-baee-43a2-b226-0728cfadd217	343.00	2025-07-22		2025-07-23 17:54:14.813481+00	2025-07-23 17:54:14.813481+00
aaf9ad90-10a3-4513-b1a5-2e71c44a267a	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	19520e84-fe1a-4742-8bf1-0586bcf6f0c0	1aa947d2-baee-43a2-b226-0728cfadd217	332.00	2025-07-08		2025-07-23 18:08:17.336895+00	2025-07-23 18:08:17.336895+00
07fdeb9e-04f2-4196-a57e-376bc2e923b0	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	e056cef7-d455-4f49-a63d-d446218db39b	649b87fe-f244-439e-a2f6-c81d64eef7ae	22.00	2025-07-15		2025-07-23 17:39:41.55145+00	2025-07-23 17:39:41.55145+00
04ec6472-aa89-4272-88d6-daaac8b31dc7	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	156a5db3-4c0d-4716-99f2-5ad8bff6bf65	649b87fe-f244-439e-a2f6-c81d64eef7ae	23.00	2025-07-08		2025-07-23 17:52:20.401043+00	2025-07-23 17:52:20.401043+00
71aa7ce7-f109-482e-a154-7ca193afbd79	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	8d7d81a4-0b07-4493-a840-acf0e56f4c4b	333753f0-78c7-401c-8a0e-abe85fa14ce6	34.00	2025-07-07	234	2025-07-23 08:24:16.288235+00	2025-07-23 08:24:16.288235+00
df195b87-d129-4f62-9a21-97f61d9516c7	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	19520e84-fe1a-4742-8bf1-0586bcf6f0c0	1aa947d2-baee-43a2-b226-0728cfadd217	423.00	2025-07-01		2025-07-23 08:40:13.633366+00	2025-07-23 08:40:13.633366+00
4968ae8b-9a15-4e45-a0ff-05ef4bc3e157	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	30a2a1c1-4c7d-4854-812b-186659d6087c	3c7d61f5-db54-42dc-b3ce-36a27ffd067e	222.00	2025-07-09	here is a good	2025-07-23 07:47:51.112945+00	2025-07-23 07:47:51.112945+00
\.


--
-- Data for Name: pipeline_stages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pipeline_stages (id, user_id, name, description, color, created_at, updated_at) FROM stdin;
649b87fe-f244-439e-a2f6-c81d64eef7ae	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	new stage		#8b5cf6	2025-07-23 07:39:01.374703+00	2025-07-23 07:39:01.374703+00
333753f0-78c7-401c-8a0e-abe85fa14ce6	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	testing		#06b6d4	2025-07-23 07:57:31.480234+00	2025-07-23 07:57:31.480234+00
3c7d61f5-db54-42dc-b3ce-36a27ffd067e	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	another one		#06b6d4	2025-07-23 08:21:05.093216+00	2025-07-23 08:21:05.093216+00
1aa947d2-baee-43a2-b226-0728cfadd217	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	completed	hello	#06b6d4	2025-07-23 08:56:27.518458+00	2025-07-23 08:56:27.518458+00
b84c0ef7-31df-4a47-96ab-7bdbc9fd155d	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	Pending		#10b981	2025-07-23 17:03:12.648642+00	2025-07-23 17:03:12.648642+00
1cba7d69-36e4-48f7-94f3-cb43061f703f	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	finish		#06b6d4	2025-07-23 17:52:38.297277+00	2025-07-23 17:52:38.297277+00
d1c97878-b1a0-451a-b82d-45b5357f9b68	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	pending lead		#f59e0b	2025-07-23 18:07:28.989962+00	2025-07-23 18:07:28.989962+00
728939b7-025e-479c-a370-09000208601f	50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	indo	specific	#3b82f6	2025-07-30 11:00:45.292371+00	2025-07-30 11:00:45.292371+00
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.profiles (id, company_name, created_at, updated_at, job_title, industry, plan, company_size, address) FROM stdin;
5ed360f8-cd12-4775-a404-3d2084fc3b95	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
78cd5a0d-4a4d-4031-9249-709fbff0bd3f	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
d7ff5b3b-4b4b-431a-96b6-cc1d07f84f7e	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
a6250657-3bc0-4b38-bf7c-93769ce0096d	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
abefe057-4be1-4852-a241-5da75443614f	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
961af7eb-1a61-47ac-9fd4-e8174218a32f	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
d9432cc7-89b9-45ab-9ffc-365a86939107	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
4f9b2352-360a-4268-b4de-23a376430f48	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
835c094d-bb0a-4ccc-97b0-228210ea817b	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
49e69cca-009a-4a4c-8322-14615c323fc5	\N	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	\N	\N	\N	\N	\N
ca3e0996-58f0-4eb2-895d-96712a7a69c1	\N	2025-04-18 13:57:39.525808+00	2025-04-18 13:57:39.525808+00	\N	\N	\N	\N	\N
50be98d3-a2a9-4aa5-9c20-44f5db9ca9e0	Premium Company Solutions	2025-04-16 17:00:18.181598+00	2025-04-16 17:00:18.181598+00	contractor	Software Tech	\N	11-50	Vdos Colony, Khammam
94ef9a8f-98e7-46ca-ad16-a9bbceef6ca6	\N	2025-04-21 15:27:18.671736+00	2025-04-21 15:27:18.671736+00	\N	\N	\N	\N	\N
4a131143-f973-4f8d-8b4b-83fafedcf9df	\N	2025-04-23 13:05:31.501325+00	2025-04-23 13:05:31.501325+00	\N	\N	\N	\N	\N
71fbf873-af4f-4f51-95f1-153ba64776e3	\N	2025-05-30 12:17:50.255863+00	2025-05-30 12:17:50.255863+00	\N	\N	\N	\N	\N
f309cbf2-fa03-4896-ba5a-7e0468336121	\N	2025-06-05 16:50:11.729965+00	2025-06-05 16:50:11.729965+00	\N	\N	\N	\N	\N
7c973d9e-05df-4652-9862-11a453b89a01	\N	2025-06-12 17:14:40.907031+00	2025-06-12 17:14:40.907031+00	\N	\N	\N	\N	\N
d194c33a-5679-4dcb-b22c-fac98cfec3cf	\N	2025-06-12 17:16:43.139419+00	2025-06-12 17:16:43.139419+00	\N	\N	\N	\N	\N
7db369b9-1144-4395-931d-abf2b3b4a4ea	Wissel Trucking, Inc	2025-06-01 22:51:17.558952+00	2025-06-01 22:51:17.558952+00	President	Excavation	\N	1-10	25945 Dee Mack Rd Washington, IL 61571
bdfdb5f8-9829-402b-bea4-55488151c677	\N	2025-06-21 20:53:11.786738+00	2025-06-21 20:53:11.786738+00	\N	\N	\N	\N	\N
543a174a-2ee1-43fd-8924-bc0e219eea23	\N	2025-07-23 17:37:20.16968+00	2025-07-23 17:37:20.16968+00	\N	\N	\N	\N	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, first_name, last_name, created_at, email, full_name, phone, address, company_name, job_title, industry, company_size, email_notifications, sms_notifications, role, updated_at) FROM stdin;
\.


--
-- Name: contents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contents_id_seq', 19, true);


--
-- Name: clients clients_email_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_email_unique UNIQUE (email, user_id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: contents contents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contents
    ADD CONSTRAINT contents_pkey PRIMARY KEY (id);


--
-- Name: estimates estimates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estimates
    ADD CONSTRAINT estimates_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_invoice_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_invoice_number_key UNIQUE (invoice_number);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: payment_info payment_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_info
    ADD CONSTRAINT payment_info_pkey PRIMARY KEY (id);


--
-- Name: pipeline_leads pipeline_leads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pipeline_leads
    ADD CONSTRAINT pipeline_leads_pkey PRIMARY KEY (id);


--
-- Name: pipeline_stages pipeline_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pipeline_stages
    ADD CONSTRAINT pipeline_stages_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id, email);


--
-- Name: clients_email_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX clients_email_idx ON public.clients USING btree (email);


--
-- Name: clients_name_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX clients_name_idx ON public.clients USING btree (name);


--
-- Name: clients_user_id_email_unique_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX clients_user_id_email_unique_idx ON public.clients USING btree (user_id, email) WHERE (email IS NOT NULL);


--
-- Name: clients_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX clients_user_id_idx ON public.clients USING btree (user_id);


--
-- Name: clients_user_id_phone_unique_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX clients_user_id_phone_unique_idx ON public.clients USING btree (user_id, phone) WHERE (phone IS NOT NULL);


--
-- Name: idx_contents_project_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contents_project_id ON public.contents USING btree (project_id);


--
-- Name: idx_invoices_estimate_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invoices_estimate_id ON public.invoices USING btree (estimate_id);


--
-- Name: idx_invoices_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invoices_status ON public.invoices USING btree (status);


--
-- Name: idx_users_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_id ON public.users USING btree (id);


--
-- Name: payment_info_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX payment_info_user_id_idx ON public.payment_info USING btree (user_id);


--
-- Name: invoices set_invoices_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- Name: contents update_contents_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_contents_updated_at BEFORE UPDATE ON public.contents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: payment_info update_payment_info_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_payment_info_updated_at BEFORE UPDATE ON public.payment_info FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();


--
-- Name: clients clients_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: contents contents_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contents
    ADD CONSTRAINT contents_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.estimates(id) ON DELETE CASCADE;


--
-- Name: estimates fk_estimate_client; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estimates
    ADD CONSTRAINT fk_estimate_client FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: estimates fk_estimate_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estimates
    ADD CONSTRAINT fk_estimate_user FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: invoices fk_invoice_client; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_invoice_client FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT;


--
-- Name: invoices invoices_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: invoices invoices_estimate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES public.estimates(id) ON DELETE SET NULL;


--
-- Name: invoices invoices_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.estimates(id);


--
-- Name: jobs jobs_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: jobs jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: payment_info payment_info_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payment_info
    ADD CONSTRAINT payment_info_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: pipeline_leads pipeline_leads_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pipeline_leads
    ADD CONSTRAINT pipeline_leads_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: pipeline_leads pipeline_leads_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pipeline_leads
    ADD CONSTRAINT pipeline_leads_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.pipeline_stages(id) ON DELETE CASCADE;


--
-- Name: pipeline_leads pipeline_leads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pipeline_leads
    ADD CONSTRAINT pipeline_leads_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: pipeline_stages pipeline_stages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pipeline_stages
    ADD CONSTRAINT pipeline_stages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id);


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: users Admins can update all profiles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admins can update all profiles" ON public.users FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.users users_1
  WHERE (((users_1.id = auth.uid()) OR (users_1.id = auth.uid())) AND (users_1.role = 'admin'::text)))));


--
-- Name: users Admins can view all profiles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admins can view all profiles" ON public.users FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users users_1
  WHERE (((users_1.id = auth.uid()) OR (users_1.id = auth.uid())) AND (users_1.role = 'admin'::text)))));


--
-- Name: invoices Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON public.invoices FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: estimates Public can create estimates; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public can create estimates" ON public.estimates FOR INSERT WITH CHECK (true);


--
-- Name: estimates Public can view estimates; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public can view estimates" ON public.estimates FOR SELECT USING (true);


--
-- Name: clients Users can delete their own clients; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own clients" ON public.clients FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: payment_info Users can delete their own payment info; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own payment info" ON public.payment_info FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: clients Users can insert their own clients; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can insert their own clients" ON public.clients FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: payment_info Users can insert their own payment info; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can insert their own payment info" ON public.payment_info FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: jobs Users can manage their own jobs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can manage their own jobs" ON public.jobs TO authenticated USING ((auth.uid() = user_id));


--
-- Name: users Users can update own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (((auth.uid() = id) OR (auth.uid() = id)));


--
-- Name: clients Users can update their own clients; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own clients" ON public.clients FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: payment_info Users can update their own payment info; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own payment info" ON public.payment_info FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: clients Users can view clients for their jobs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view clients for their jobs" ON public.clients FOR SELECT TO authenticated USING ((id IN ( SELECT jobs.client_id
   FROM public.jobs
  WHERE (jobs.user_id = auth.uid()))));


--
-- Name: users Users can view own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (((auth.uid() = id) OR (auth.uid() = id)));


--
-- Name: clients Users can view their own clients; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own clients" ON public.clients FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: payment_info Users can view their own payment info; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own payment info" ON public.payment_info FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: estimates; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.estimates ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_new_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION handle_user_update(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_user_update() TO anon;
GRANT ALL ON FUNCTION public.handle_user_update() TO authenticated;
GRANT ALL ON FUNCTION public.handle_user_update() TO service_role;


--
-- Name: TABLE clients; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.clients TO anon;
GRANT ALL ON TABLE public.clients TO authenticated;
GRANT ALL ON TABLE public.clients TO service_role;


--
-- Name: FUNCTION search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, filter_id_arg uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, filter_id_arg uuid) TO anon;
GRANT ALL ON FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, filter_id_arg uuid) TO authenticated;
GRANT ALL ON FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, filter_id_arg uuid) TO service_role;


--
-- Name: FUNCTION search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, sort_column text, sort_direction text, filter_id_arg uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, sort_column text, sort_direction text, filter_id_arg uuid) TO anon;
GRANT ALL ON FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, sort_column text, sort_direction text, filter_id_arg uuid) TO authenticated;
GRANT ALL ON FUNCTION public.search_clients_by_user(search_term text, user_id_arg uuid, page_num integer, page_size integer, sort_column text, sort_direction text, filter_id_arg uuid) TO service_role;


--
-- Name: FUNCTION search_clients_by_user_count(search_term text, user_id_arg uuid, filter_id_arg uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_clients_by_user_count(search_term text, user_id_arg uuid, filter_id_arg uuid) TO anon;
GRANT ALL ON FUNCTION public.search_clients_by_user_count(search_term text, user_id_arg uuid, filter_id_arg uuid) TO authenticated;
GRANT ALL ON FUNCTION public.search_clients_by_user_count(search_term text, user_id_arg uuid, filter_id_arg uuid) TO service_role;


--
-- Name: FUNCTION search_estimates(search_term text, user_id_arg uuid, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_estimates(search_term text, user_id_arg uuid, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) TO anon;
GRANT ALL ON FUNCTION public.search_estimates(search_term text, user_id_arg uuid, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) TO authenticated;
GRANT ALL ON FUNCTION public.search_estimates(search_term text, user_id_arg uuid, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) TO service_role;


--
-- Name: FUNCTION search_estimates_count(search_term text, user_id_arg uuid, filter_id_arg uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_estimates_count(search_term text, user_id_arg uuid, filter_id_arg uuid) TO anon;
GRANT ALL ON FUNCTION public.search_estimates_count(search_term text, user_id_arg uuid, filter_id_arg uuid) TO authenticated;
GRANT ALL ON FUNCTION public.search_estimates_count(search_term text, user_id_arg uuid, filter_id_arg uuid) TO service_role;


--
-- Name: FUNCTION search_invoices(search_term text, user_id_arg text, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_invoices(search_term text, user_id_arg text, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) TO anon;
GRANT ALL ON FUNCTION public.search_invoices(search_term text, user_id_arg text, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) TO authenticated;
GRANT ALL ON FUNCTION public.search_invoices(search_term text, user_id_arg text, filter_id_arg uuid, sort_column text, sort_direction text, page_num integer, page_size integer) TO service_role;


--
-- Name: FUNCTION search_invoices_count(search_term text, user_id_arg text, filter_id_arg uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_invoices_count(search_term text, user_id_arg text, filter_id_arg uuid) TO anon;
GRANT ALL ON FUNCTION public.search_invoices_count(search_term text, user_id_arg text, filter_id_arg uuid) TO authenticated;
GRANT ALL ON FUNCTION public.search_invoices_count(search_term text, user_id_arg text, filter_id_arg uuid) TO service_role;


--
-- Name: FUNCTION sync_auth_to_public_users(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.sync_auth_to_public_users() TO anon;
GRANT ALL ON FUNCTION public.sync_auth_to_public_users() TO authenticated;
GRANT ALL ON FUNCTION public.sync_auth_to_public_users() TO service_role;


--
-- Name: FUNCTION update_modified_column(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_modified_column() TO anon;
GRANT ALL ON FUNCTION public.update_modified_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_modified_column() TO service_role;


--
-- Name: FUNCTION update_updated_at_column(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_updated_at_column() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO service_role;


--
-- Name: TABLE contents; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.contents TO anon;
GRANT ALL ON TABLE public.contents TO authenticated;
GRANT ALL ON TABLE public.contents TO service_role;


--
-- Name: SEQUENCE contents_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.contents_id_seq TO anon;
GRANT ALL ON SEQUENCE public.contents_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.contents_id_seq TO service_role;


--
-- Name: TABLE estimates; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.estimates TO anon;
GRANT ALL ON TABLE public.estimates TO authenticated;
GRANT ALL ON TABLE public.estimates TO service_role;


--
-- Name: TABLE invoices; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.invoices TO anon;
GRANT ALL ON TABLE public.invoices TO authenticated;
GRANT ALL ON TABLE public.invoices TO service_role;


--
-- Name: TABLE jobs; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.jobs TO anon;
GRANT ALL ON TABLE public.jobs TO authenticated;
GRANT ALL ON TABLE public.jobs TO service_role;


--
-- Name: TABLE payment_info; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.payment_info TO anon;
GRANT ALL ON TABLE public.payment_info TO authenticated;
GRANT ALL ON TABLE public.payment_info TO service_role;


--
-- Name: TABLE pipeline_leads; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.pipeline_leads TO anon;
GRANT ALL ON TABLE public.pipeline_leads TO authenticated;
GRANT ALL ON TABLE public.pipeline_leads TO service_role;


--
-- Name: TABLE pipeline_stages; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.pipeline_stages TO anon;
GRANT ALL ON TABLE public.pipeline_stages TO authenticated;
GRANT ALL ON TABLE public.pipeline_stages TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE user_profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_profiles TO anon;
GRANT ALL ON TABLE public.user_profiles TO authenticated;
GRANT ALL ON TABLE public.user_profiles TO service_role;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- PostgreSQL database dump complete
--

