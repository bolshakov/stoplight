-- Records a recovery-probe success. Postgres analogue of
-- lua_scripts/record_recovery_probe_success.lua.
CREATE OR REPLACE FUNCTION stoplight_record_recovery_probe_success(
  p_light        text,
  p_occurred_at  timestamptz
) RETURNS void AS $$
BEGIN
  INSERT INTO stoplight_recovery_metrics (light, last_success_at, consecutive_successes, consecutive_errors)
  VALUES (p_light, p_occurred_at, 1, 0)
  ON CONFLICT (light) DO UPDATE SET
    last_success_at       = GREATEST(stoplight_recovery_metrics.last_success_at, p_occurred_at),
    consecutive_successes = stoplight_recovery_metrics.consecutive_successes + 1,
    consecutive_errors    = 0;
END;
$$ LANGUAGE plpgsql;
