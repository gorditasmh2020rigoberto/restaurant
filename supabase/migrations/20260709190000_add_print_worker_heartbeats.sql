-- Cada print-worker (uno por Raspberry Pi) escribe aquí cada ~20s para
-- que la app de Caja pueda mostrar un LED verde/rojo por impresora sin
-- tener que conectarse a las Raspberries a mano. Ver print-worker/index.js
-- (sendHeartbeat) y lib/views/print_status_view.dart (los LEDs).
CREATE TABLE IF NOT EXISTS print_worker_heartbeats (
  id TEXT PRIMARY KEY, -- "<branch_name>:<print_area>", ej. "Maravillas:drinks"
  branch_name TEXT NOT NULL,
  print_area TEXT NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS print_worker_heartbeats_branch_idx
  ON print_worker_heartbeats (branch_name);
