-- Transitions a light to RED. Postgres analogue of lua_scripts/transition_to_red.lua.
-- First-writer-wins: the guarded UPDATE takes a row lock, so under concurrent
-- callers exactly one sets breached_at and returns true. p_now / p_scheduled_after
-- are supplied by the application (Ruby clock).
CREATE OR REPLACE FUNCTION stoplight_transition_to_red(
  p_light            text,
  p_now              timestamptz,
  p_scheduled_after  timestamptz
) RETURNS boolean AS $$
DECLARE
  v_flipped integer;
BEGIN
  INSERT INTO stoplight_states (light) VALUES (p_light)
  ON CONFLICT (light) DO NOTHING;

  UPDATE stoplight_states
  SET breached_at = p_now, recovery_scheduled_after = p_scheduled_after,
      recovery_started_at = NULL, recovered_at = NULL
  WHERE light = p_light AND breached_at IS NULL;

  GET DIAGNOSTICS v_flipped = ROW_COUNT;

  IF v_flipped = 1 THEN
    RETURN true;
  END IF;

  UPDATE stoplight_states
  SET recovery_scheduled_after = p_scheduled_after, recovery_started_at = NULL, recovered_at = NULL
  WHERE light = p_light;

  RETURN false;
END;
$$ LANGUAGE plpgsql;
