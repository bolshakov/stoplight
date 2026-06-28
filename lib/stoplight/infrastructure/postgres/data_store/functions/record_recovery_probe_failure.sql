-- Records a recovery-probe failure. Postgres analogue of
-- lua_scripts/record_recovery_probe_failure.lua. Recovery metrics are not
-- windowed, so no events are written — only the counter row is upserted.
CREATE OR REPLACE FUNCTION stoplight_record_recovery_probe_failure(
  p_light          text,
  p_occurred_at    timestamptz,
  p_error_class    text,
  p_error_message  text
) RETURNS void AS $$
BEGIN
  INSERT INTO stoplight_recovery_metrics (light, last_error_class, last_error_message, last_error_at, consecutive_errors, consecutive_successes)
  VALUES (p_light, p_error_class, p_error_message, p_occurred_at, 1, 0)
  ON CONFLICT (light) DO UPDATE SET
    last_error_class   = CASE WHEN stoplight_recovery_metrics.last_error_at IS NULL OR p_occurred_at > stoplight_recovery_metrics.last_error_at THEN EXCLUDED.last_error_class   ELSE stoplight_recovery_metrics.last_error_class END,
    last_error_message = CASE WHEN stoplight_recovery_metrics.last_error_at IS NULL OR p_occurred_at > stoplight_recovery_metrics.last_error_at THEN EXCLUDED.last_error_message ELSE stoplight_recovery_metrics.last_error_message END,
    last_error_at      = GREATEST(stoplight_recovery_metrics.last_error_at, p_occurred_at),
    consecutive_errors = stoplight_recovery_metrics.consecutive_errors + 1,
    consecutive_successes = 0;
END;
$$ LANGUAGE plpgsql;
