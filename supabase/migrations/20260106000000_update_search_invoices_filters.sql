CREATE OR REPLACE FUNCTION search_invoices (
    search_term TEXT,
    user_id_arg TEXT,
    filter_id_arg UUID,
    sort_column TEXT DEFAULT 'created_at',
    sort_direction TEXT DEFAULT 'DESC',
    page_num INT DEFAULT 1,
    page_size INT DEFAULT 10,
    filter_status_arg TEXT DEFAULT NULL,
    filter_project_id_arg UUID DEFAULT NULL,
    filter_client_id_arg UUID DEFAULT NULL
) RETURNS TABLE (
  id uuid,
  user_id text,
  client_id uuid,
  project_id uuid,
  invoice_number character varying(10),
  issue_date timestamptz,
  due_date timestamptz,
  invoice_total_amount numeric,
  line_items jsonb,
  invoice_summary text,
  remit_payment jsonb,
  additional_notes text,
  created_at timestamptz,
  updated_at timestamptz,
  status character varying(20),
  estimate_id uuid,
  client json,
  project json
) AS $$
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
          (%3$L IS NULL OR i.status = %3$L) AND
          (%4$L IS NULL OR i.project_id = %4$L) AND
          (%5$L IS NULL OR i.client_id = %5$L) AND
          (%6$L IS NULL OR %6$L = '''' OR
              i.invoice_number ILIKE %7$L OR
              i.status ILIKE %7$L OR
              c.name ILIKE %7$L OR
              c.email ILIKE %7$L OR
              p."projectName" ILIKE %7$L
          )
      ORDER BY %8$I %9$s',
      user_id_arg,      -- 1
      filter_id_arg,    -- 2
      filter_status_arg, -- 3
      filter_project_id_arg, -- 4
      filter_client_id_arg, -- 5
      search_term,      -- 6
      search_pattern,   -- 7
      sort_column,      -- 8
      valid_sort_direction -- 9
    );

    IF page_size != -1 THEN
        query_str := query_str || format(' LIMIT %s OFFSET %s', page_size, offset_val);
    END IF;

    RETURN QUERY EXECUTE query_str;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION search_invoices_count(
    search_term TEXT,
    user_id_arg TEXT,
    filter_id_arg UUID,
    filter_status_arg TEXT DEFAULT NULL,
    filter_project_id_arg UUID DEFAULT NULL,
    filter_client_id_arg UUID DEFAULT NULL
)
RETURNS INT AS $$
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
        (filter_status_arg IS NULL OR i.status = filter_status_arg) AND
        (filter_project_id_arg IS NULL OR i.project_id = filter_project_id_arg) AND
        (filter_client_id_arg IS NULL OR i.client_id = filter_client_id_arg) AND
        (search_term IS NULL OR search_term = '' OR
            i.invoice_number ILIKE '%' || search_term || '%' OR
            i.status ILIKE '%' || search_term || '%' OR
            c.name ILIKE '%' || search_term || '%' OR
            c.email ILIKE '%' || search_term || '%' OR
            p."projectName" ILIKE '%' || search_term || '%'
        );
    RETURN total_records;
END;
$$ LANGUAGE plpgsql;

