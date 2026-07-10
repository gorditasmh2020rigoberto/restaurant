-- print_worker_heartbeats se creó por SQL Editor sin activar Realtime,
-- así que la app de Caja solo recibía el dato UNA vez al cargar la
-- página (el fetch inicial de .stream()) pero nunca las actualizaciones
-- en vivo que cada Raspberry manda cada 20s — los LEDs se quedaban
-- pegados con el primer dato y se veían "desconectados" después de 45s
-- aunque las Raspberries sí siguieran mandando su heartbeat.
ALTER PUBLICATION supabase_realtime ADD TABLE print_worker_heartbeats;
