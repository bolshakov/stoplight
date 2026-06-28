-- Reads request metrics. Postgres analogue of lua_scripts/get_metrics.lua.
-- Returns raw windowed counts (NULL when not windowed) plus the metadata row;
-- the caller clamps consecutive counters to the in-window counts, mirroring the
-- memory adapter. p_window_start is supplied by the application (Ruby clock).
--
-- The windowed errors/successes counts come from a SINGLE scan of stoplight_events
-- via conditional aggregation (count(*) FILTER (...)), not two separate count(*)
-- subqueries.
CREATE OR REPLACE FUNCTION stoplight_get_metrics(
  p_light         text,
  p_windowed      boolean,
  p_window_start  timestamptz
) RETURNS TABLE (
  errors                 bigint,
  successes              bigint,
  consecutive_errors     integer,
  consecutive_successes  integer,
  last_error_class       text,
  last_error_message     text,
  last_error_at          timestamptz,
  last_success_at        timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    CASE WHEN p_windowed THEN ev.errors ELSE NULL END,
    CASE WHEN p_windowed THEN ev.successes ELSE NULL END,
    COALESCE(m.consecutive_errors, 0),
    COALESCE(m.consecutive_successes, 0),
    m.last_error_class,
    m.last_error_message,
    m.last_error_at,
    m.last_success_at
  FROM (SELECT p_light AS light) base
  LEFT JOIN stoplight_metadata m ON m.light = base.light
  LEFT JOIN LATERAL (
    SELECT
      count(*) FILTER (WHERE metric = 'errors')    AS errors,
      count(*) FILTER (WHERE metric = 'successes') AS successes
    FROM stoplight_events
    WHERE p_windowed AND light = p_light AND occurred_at >= p_window_start
  ) ev ON true;
END;
$$ LANGUAGE plpgsql;
