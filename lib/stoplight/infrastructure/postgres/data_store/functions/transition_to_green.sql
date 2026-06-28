-- Transitions a light to GREEN. Postgres analogue of lua_scripts/transition_to_green.lua.
-- Guard: recovered_at IS NULL. First writer wins. If already recovered, makes no
-- change and returns false (mirrors the memory adapter).
CREATE OR REPLACE FUNCTION stoplight_transition_to_green(
  p_light  text,
  p_now    timestamptz
) RETURNS boolean AS $$
DECLARE
  v_flipped integer;
BEGIN
  INSERT INTO stoplight_states (light) VALUES (p_light)
  ON CONFLICT (light) DO NOTHING;

  UPDATE stoplight_states
  SET recovered_at = p_now,
      recovery_started_at = NULL, breached_at = NULL, recovery_scheduled_after = NULL
  WHERE light = p_light AND recovered_at IS NULL;

  GET DIAGNOSTICS v_flipped = ROW_COUNT;
  RETURN v_flipped = 1;
END;
$$ LANGUAGE plpgsql;
