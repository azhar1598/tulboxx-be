-- Drop old versions of the functions to be safe
DROP FUNCTION IF EXISTS search_estimates(text, uuid, uuid, text, text, int, int);
DROP FUNCTION IF EXISTS search_estimates_count(text, uuid, uuid);
DROP FUNCTION IF EXISTS search_estimates(text, uuid, bigint, text, text, int, int);
DROP FUNCTION IF EXISTS search_estimates_count(text, uuid, bigint);
DROP FUNCTION IF EXISTS search_estimates(uuid, text, text, text, int, int);
DROP FUNCTION IF EXISTS search_estimates_count(uuid, text);


CREATE OR REPLACE FUNCTION search_estimates (
    search_term TEXT,
    user_id_arg UUID,
    filter_id_arg UUID,
    sort_column TEXT DEFAULT 'created_at',
    sort_direction TEXT DEFAULT 'DESC',
    page_num INT DEFAULT 1,
    page_size INT DEFAULT 10
) RETURNS TABLE (
  id uuid,
  user_id uuid,
  client_id uuid,
  "projectName" text,
  type text,
  "serviceType" text,
  "problemDescription" text,
  "solutionDescription" text,
  "projectEstimate" text,
  "projectStartDate" text,
  "projectEndDate" text,
  "lineItems" jsonb,
  "equipmentMaterials" text,
  "additionalNotes" text,
  ai_generated_estimate text,
  total_amount numeric,
  created_at timestamptz,
  updated_at date,
  status text,
  clients json
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION search_estimates_count(
    search_term TEXT,
    user_id_arg UUID,
    filter_id_arg UUID
)
RETURNS INT AS $$
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
$$ LANGUAGE plpgsql; 