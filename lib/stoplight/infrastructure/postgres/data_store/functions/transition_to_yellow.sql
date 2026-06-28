-- Transitions a light to YELLOW. Postgres analogue of lua_scripts/transition_to_yellow.lua.
-- Guard: recovery_started_at IS NULL. First writer wins; subsequent callers clear
-- the other timestamps and return false (mirrors the memory adapter).
CREATE OR REPLACE FUNCTION stoplight_transition_to_yellow(
  p_light  text,
  p_now    timestamptz
) RETURNS boolean AS $$
DECLARE
  v_flipped integer;
BEGIN
  INSERT INTO stoplight_states (light) VALUES (p_light)
  ON CONFLICT (light) DO NOTHING;

  UPDATE stoplight_states
  SET recovery_started_at = p_now,
      recovery_scheduled_after = NULL, recovered_at = NULL, breached_at = NULL
  WHERE light = p_light AND recovery_started_at IS NULL;

  GET DIAGNOSTICS v_flipped = ROW_COUNT;

  IF v_flipped = 1 THEN
    RETURN true;
  END IF;

  UPDATE stoplight_states
  SET recovery_scheduled_after = NULL, recovered_at = NULL, breached_at = NULL
  WHERE light = p_light;

  RETURN false;
END;
$$ LANGUAGE plpgsql;
