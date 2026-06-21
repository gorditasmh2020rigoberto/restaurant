#!/usr/bin/env python3
"""
Kitchen display ligero para Raspberry Pi Zero 2W (o cualquier Pi con
poca RAM). Usa Tkinter + polling REST a Supabase. ~30-50 MB de RAM en
runtime, vs los 400+ MB de Chromium con la PWA.

Config: ~/.kitchen-display.conf (formato KEY=VALUE).

Lanzar manualmente:
    python3 kitchen_display.py

Salir: Escape o Alt+F4.
"""

import json
import os
import sys
import tkinter as tk
from tkinter import font as tkfont
from datetime import datetime, timezone
from urllib import request, parse, error

# ── Config ──────────────────────────────────────────────────────────
CONFIG_FILE = os.path.expanduser("~/.kitchen-display.conf")


def load_config(path):
    """Parser minimalista de archivos KEY=VALUE estilo .env."""
    conf = {}
    if not os.path.exists(path):
        return conf
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            k, v = line.split("=", 1)
            conf[k.strip()] = v.strip().strip('"').strip("'")
    return conf


CONF = load_config(CONFIG_FILE)
SUPABASE_URL = CONF.get("SUPABASE_URL") or os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = (
    CONF.get("SUPABASE_SERVICE_KEY")
    or CONF.get("SUPABASE_KEY")
    or os.environ.get("SUPABASE_SERVICE_KEY", "")
)
BRANCH_NAME = CONF.get("BRANCH_NAME") or os.environ.get("BRANCH_NAME", "")
RESTAURANT_NAME = (
    CONF.get("RESTAURANT_NAME")
    or os.environ.get("RESTAURANT_NAME", "GORDITAS MIS HERMANAS")
)
POLL_INTERVAL_MS = int(
    CONF.get("POLL_INTERVAL_MS") or os.environ.get("POLL_INTERVAL_MS", "3000")
)
VIEW_MODE = (CONF.get("KITCHEN_VIEW") or "cocina").lower()  # cocina / cocina-llevar / barra

if not SUPABASE_URL or not SUPABASE_KEY or not BRANCH_NAME:
    print(
        f"✘ Faltan vars en {CONFIG_FILE}: SUPABASE_URL, "
        f"SUPABASE_SERVICE_KEY, BRANCH_NAME"
    )
    sys.exit(1)


DRINK_CATEGORIES = {"drink", "alcohol", "bebidas", "drinks"}


def is_drink(item):
    """Misma regla que el print-worker / kitchen_view de Flutter."""
    dish = item.get("dishes") or {}
    cat = (dish.get("category") or "").strip().lower()
    return cat in DRINK_CATEGORIES


def filter_items_by_view(order):
    """Filtra los items según VIEW_MODE (cocina/cocina-llevar/barra)."""
    items = order.get("order_items") or []
    if VIEW_MODE == "barra":
        return [i for i in items if is_drink(i)]
    if VIEW_MODE == "cocina-llevar":
        if (order.get("order_type") or "").lower() not in {"to_go", "para_llevar", "delivery"}:
            return []
        return [i for i in items if not is_drink(i)]
    # 'cocina' default → comida (no bebidas)
    return [i for i in items if not is_drink(i)]


# ── HTTP a Supabase REST (PostgREST) ─────────────────────────────────
def fetch_orders():
    """Trae órdenes activas (sent_to_kitchen_at NOT NULL, sin marcar listas)."""
    select = (
        "id,branch_name,order_type,table_id,waiter_id,sent_to_kitchen_at,"
        "created_at,customer_name,"
        "restaurant_tables(table_number),"
        "waiters(name),"
        "order_items(id,quantity,guisados_selected,client_label,"
        "printed_at,dishes(name,category))"
    )
    params = {
        "branch_name": f"eq.{BRANCH_NAME}",
        "sent_to_kitchen_at": "not.is.null",
        # Solo órdenes con al menos un item sin imprimir. Sin este
        # filtro el `limit=30` se llenaba de órdenes viejas todas
        # completadas y la orden nueva real ni siquiera entraba al
        # lote → la pantalla mostraba "Sin órdenes pendientes".
        "printed_at": "is.null",
        "order": "sent_to_kitchen_at.asc",
        "limit": "30",
        "select": select,
    }
    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/orders?{parse.urlencode(params)}"
    req = request.Request(
        url,
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Accept": "application/json",
        },
    )
    with request.urlopen(req, timeout=8) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fmt_time(iso_str):
    if not iso_str:
        return ""
    try:
        # Postgres timestamps llegan como "2026-06-20T03:34:25.075440+00:00"
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        # Convierte a hora local
        local = dt.astimezone()
        return local.strftime("%H:%M")
    except Exception:
        return iso_str[:16]


def parse_guisados(raw):
    if not raw:
        return []
    try:
        arr = json.loads(raw)
        return [g for g in arr if g]
    except Exception:
        return []


def strip_accents(s):
    """Solo cosmético — la pantalla sí soporta unicode, esto es opcional."""
    if not s:
        return s
    import unicodedata
    return "".join(
        c for c in unicodedata.normalize("NFD", str(s))
        if unicodedata.category(c) != "Mn"
    )


# ── UI Tkinter ──────────────────────────────────────────────────────
BG_DARK = "#0a0a0a"
BG_CARD = "#1a1a1a"
BG_CARD_NEW = "#1a2a1a"  # tinte verde para órdenes nuevas
FG_TEXT = "#ffffff"
FG_MUTED = "#888888"
FG_ACCENT = "#ffd23f"  # amarillo
FG_RED = "#ff6b6b"
FG_GREEN = "#6bcf7f"


class KitchenApp:
    def __init__(self, root):
        self.root = root
        self.previous_order_ids = set()

        root.title(f"Kitchen Display — {BRANCH_NAME}")
        root.configure(bg=BG_DARK)
        try:
            root.attributes("-fullscreen", True)
        except tk.TclError:
            pass
        root.bind("<Escape>", lambda e: root.destroy())
        root.bind("<F11>", lambda e: root.attributes(
            "-fullscreen", not root.attributes("-fullscreen")
        ))

        # Tamaños de fuente: ajusta según resolución del monitor.
        self.f_header = tkfont.Font(family="DejaVu Sans", size=20, weight="bold")
        self.f_sub = tkfont.Font(family="DejaVu Sans", size=12)
        self.f_card_title = tkfont.Font(family="DejaVu Sans", size=16, weight="bold")
        self.f_item = tkfont.Font(family="DejaVu Sans Mono", size=14)
        self.f_status = tkfont.Font(family="DejaVu Sans", size=10)

        # ── Header
        header_frame = tk.Frame(root, bg=BG_DARK)
        header_frame.pack(fill="x", padx=12, pady=(8, 4))
        tk.Label(
            header_frame, text=RESTAURANT_NAME, fg=FG_ACCENT, bg=BG_DARK,
            font=self.f_header,
        ).pack(side="left")
        tk.Label(
            header_frame,
            text=f"{VIEW_MODE.upper()} • {BRANCH_NAME}",
            fg=FG_MUTED, bg=BG_DARK, font=self.f_sub,
        ).pack(side="right")

        # Separator
        tk.Frame(root, bg="#333333", height=1).pack(fill="x", padx=12, pady=4)

        # ── Canvas scrollable de órdenes
        body = tk.Frame(root, bg=BG_DARK)
        body.pack(fill="both", expand=True, padx=12, pady=4)

        self.canvas = tk.Canvas(body, bg=BG_DARK, highlightthickness=0)
        self.scrollbar = tk.Scrollbar(
            body, orient="vertical", command=self.canvas.yview,
            bg=BG_CARD, troughcolor=BG_DARK, activebackground=FG_ACCENT,
        )
        self.cards_frame = tk.Frame(self.canvas, bg=BG_DARK)
        self.cards_frame_id = self.canvas.create_window(
            (0, 0), window=self.cards_frame, anchor="nw"
        )
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.canvas.pack(side="left", fill="both", expand=True)
        self.scrollbar.pack(side="right", fill="y")

        self.cards_frame.bind(
            "<Configure>",
            lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")),
        )
        # Al cambiar el ancho del canvas, ajusta el ancho del frame interno
        # para que las cards llenen horizontalmente.
        self.canvas.bind(
            "<Configure>",
            lambda e: self.canvas.itemconfig(self.cards_frame_id, width=e.width),
        )
        # Scroll con mouse wheel
        self.canvas.bind_all("<Button-4>", lambda e: self.canvas.yview_scroll(-1, "units"))
        self.canvas.bind_all("<Button-5>", lambda e: self.canvas.yview_scroll(1, "units"))

        # ── Status bar
        self.status_var = tk.StringVar(value="Conectando…")
        tk.Label(
            root, textvariable=self.status_var, fg=FG_MUTED, bg=BG_DARK,
            font=self.f_status, anchor="w",
        ).pack(fill="x", padx=12, pady=(4, 6))

        # Primer fetch
        self.poll()

    def poll(self):
        try:
            orders = fetch_orders()
            self.render(orders)
            self.status_var.set(
                f"✓ {len(orders)} órden(es) activa(s) • "
                f"Última actualización: {datetime.now().strftime('%H:%M:%S')}"
            )
        except error.URLError as e:
            self.status_var.set(f"✘ Sin conexión: {e.reason}")
        except Exception as e:
            self.status_var.set(f"✘ Error: {str(e)[:120]}")
        finally:
            self.root.after(POLL_INTERVAL_MS, self.poll)

    def render(self, orders):
        # Calcula un "fingerprint" simple del estado para evitar redraws
        # innecesarios. Si el set de IDs + cantidad de items pendientes
        # por orden no cambió, no tocamos los widgets → cero flicker.
        new_state = []
        for order in orders:
            items_for_view = filter_items_by_view(order)
            pending = [i for i in items_for_view if not i.get("printed_at")]
            if not pending:
                continue
            new_state.append((order["id"], len(pending), order.get("sent_to_kitchen_at")))
        new_state_key = tuple(new_state)

        if new_state_key == getattr(self, "_last_state_key", None):
            return  # nada cambió, no re-renderizamos

        # Estado cambió → redibuja. Esto sigue siendo destructivo pero
        # ahora solo pasa cuando hay un cambio real (orden nueva, item
        # marcado, orden completada), no en cada poll.
        self._last_state_key = new_state_key

        for w in self.cards_frame.winfo_children():
            w.destroy()

        current_ids = set()
        any_shown = False

        for order in orders:
            items_for_view = filter_items_by_view(order)
            pending = [i for i in items_for_view if not i.get("printed_at")]
            if not pending:
                continue
            current_ids.add(order["id"])
            self.render_card(order, pending)
            any_shown = True

        if not any_shown:
            empty = tk.Label(
                self.cards_frame,
                text="Sin órdenes pendientes",
                fg=FG_MUTED, bg=BG_DARK,
                font=self.f_card_title,
            )
            empty.pack(pady=40)

        self.previous_order_ids = current_ids

    def render_card(self, order, items):
        is_new = order["id"] not in self.previous_order_ids
        bg = BG_CARD_NEW if is_new else BG_CARD

        card = tk.Frame(
            self.cards_frame, bg=bg, bd=0, relief="flat",
            highlightthickness=1, highlightbackground="#2a2a2a",
        )
        card.pack(fill="x", pady=4, padx=2)
        inner = tk.Frame(card, bg=bg)
        inner.pack(fill="x", padx=12, pady=10)

        # Línea 1: Mesa / Mesero / hora / id corto
        table = (order.get("restaurant_tables") or {}).get("table_number")
        waiter = (order.get("waiters") or {}).get("name", "")
        oid_short = order["id"][:8]
        hora = fmt_time(order.get("sent_to_kitchen_at") or order.get("created_at"))

        if table is not None:
            left = f"MESA {table}"
        else:
            tipo = (order.get("order_type") or "").upper()
            left = tipo or "ORDEN"

        header = tk.Frame(inner, bg=bg)
        header.pack(fill="x")
        tk.Label(
            header, text=left, fg=FG_ACCENT, bg=bg,
            font=self.f_card_title, anchor="w",
        ).pack(side="left")
        if waiter:
            tk.Label(
                header, text=f"  •  {waiter}", fg=FG_TEXT, bg=bg,
                font=self.f_card_title, anchor="w",
            ).pack(side="left")
        tk.Label(
            header, text=f"{hora}  #{oid_short}", fg=FG_MUTED, bg=bg,
            font=self.f_sub,
        ).pack(side="right")

        # Items
        for it in items:
            qty = it.get("quantity", 1)
            dish = it.get("dishes") or {}
            name = strip_accents(dish.get("name", "?"))
            line = tk.Label(
                inner, text=f"  {qty} × {name}", fg=FG_TEXT, bg=bg,
                font=self.f_item, anchor="w", justify="left",
            )
            line.pack(fill="x")
            guisados = parse_guisados(it.get("guisados_selected"))
            if guisados:
                sub = ", ".join(strip_accents(g) for g in guisados)
                tk.Label(
                    inner, text=f"        {sub}", fg=FG_GREEN, bg=bg,
                    font=self.f_item, anchor="w", justify="left",
                ).pack(fill="x")
            label = it.get("client_label")
            if label and label != "Cliente 1":
                tk.Label(
                    inner, text=f"        ({strip_accents(label)})",
                    fg=FG_MUTED, bg=bg, font=self.f_sub, anchor="w",
                ).pack(fill="x")


def main():
    root = tk.Tk()
    KitchenApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
