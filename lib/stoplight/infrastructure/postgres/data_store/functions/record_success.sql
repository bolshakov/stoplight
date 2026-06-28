-- Records a request success. Postgres analogue of lua_scripts/record_success.lua.
-- See record_failure for the timestamp/clock policy and the amortized (~10%) prune.
CREATE OR REPLACE FUNCTION stoplight_record_success(
  p_light         text,
  p_event_id      text,
  p_occurred_at   timestamptz,
  p_windowed      boolean,
  p_prune_before  timestamptz
) RETURNS void AS $$
BEGIN
  IF p_windowed THEN
    INSERT INTO stoplight_events (light, metric, event_id, occurred_at)
    VALUES (p_light, 'successes', p_event_id, p_occurred_at);

    IF random() < 0.1 THEN
      DELETE FROM stoplight_events
      WHERE light = p_light AND metric = 'successes' AND occurred_at < p_prune_before;
    END IF;
  END IF;

  INSERT INTO stoplight_metadata (light, last_success_at, consecutive_successes, consecutive_errors)
  VALUES (p_light, p_occurred_at, 1, 0)
  ON CONFLICT (light) DO UPDATE SET
    last_success_at       = GREATEST(stoplight_metadata.last_success_at, p_occurred_at),
    consecutive_successes = stoplight_metadata.consecutive_successes + 1,
    consecutive_errors    = 0;
END;
$$ LANGUAGE plpgsql;
