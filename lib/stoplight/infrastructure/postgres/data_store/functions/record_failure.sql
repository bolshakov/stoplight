-- Records a request failure. Postgres analogue of lua_scripts/record_failure.lua.
-- All timestamps are supplied by the application (Ruby clock), never now(),
-- so Timecop and cross-node semantics match the memory/Redis adapters.
--
-- When p_windowed is true, appends an 'errors' event and, on ~10% of writes,
-- prunes events older than p_prune_before (window_size + retention margin). The
-- prune is amortized (probabilistic) rather than run on every write to avoid
-- write amplification on the hot path; events outside the window are never
-- counted by stoplight_get_metrics regardless, so this only bounds storage. The
-- metadata upsert keeps the newest last_error (guarded on timestamp) and bumps
-- the consecutive error counter while resetting consecutive successes.
CREATE OR REPLACE FUNCTION stoplight_record_failure(
  p_light          text,
  p_event_id       text,
  p_occurred_at    timestamptz,
  p_error_class    text,
  p_error_message  text,
  p_windowed       boolean,
  p_prune_before   timestamptz
) RETURNS void AS $$
BEGIN
  IF p_windowed THEN
    INSERT INTO stoplight_events (light, metric, event_id, occurred_at)
    VALUES (p_light, 'errors', p_event_id, p_occurred_at);

    IF random() < 0.1 THEN
      DELETE FROM stoplight_events
      WHERE light = p_light AND metric = 'errors' AND occurred_at < p_prune_before;
    END IF;
  END IF;

  INSERT INTO stoplight_metadata (light, last_error_class, last_error_message, last_error_at, consecutive_errors, consecutive_successes)
  VALUES (p_light, p_error_class, p_error_message, p_occurred_at, 1, 0)
  ON CONFLICT (light) DO UPDATE SET
    last_error_class   = CASE WHEN stoplight_metadata.last_error_at IS NULL OR p_occurred_at > stoplight_metadata.last_error_at THEN EXCLUDED.last_error_class   ELSE stoplight_metadata.last_error_class END,
    last_error_message = CASE WHEN stoplight_metadata.last_error_at IS NULL OR p_occurred_at > stoplight_metadata.last_error_at THEN EXCLUDED.last_error_message ELSE stoplight_metadata.last_error_message END,
    last_error_at      = GREATEST(stoplight_metadata.last_error_at, p_occurred_at),
    consecutive_errors = stoplight_metadata.consecutive_errors + 1,
    consecutive_successes = 0;
END;
$$ LANGUAGE plpgsql;
