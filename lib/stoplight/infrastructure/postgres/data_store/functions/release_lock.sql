-- Releases a recovery lock if held by this token. Postgres analogue of
-- lua_scripts/release_lock.lua (token comparison prevents releasing another
-- holder's lock). Acquisition stays inline in the adapter (single INSERT ...
-- ON CONFLICT), mirroring Redis where acquire is a plain SET NX.
CREATE OR REPLACE FUNCTION stoplight_release_lock(
  p_light  text,
  p_token  text
) RETURNS void AS $$
BEGIN
  DELETE FROM stoplight_locks WHERE light = p_light AND token = p_token;
END;
$$ LANGUAGE plpgsql;
