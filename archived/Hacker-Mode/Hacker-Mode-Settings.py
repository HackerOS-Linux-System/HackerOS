#!/usr/bin/env python3

import tkinter as tk
from tkinter import font as tkfont, ttk, messagebox, scrolledtext
from PIL import Image, ImageTk
import subprocess
import os
import getpass
import locale
import logging
import threading
import psutil
import time
import sys
import re
import platform

# Configure logging for debugging
logging.basicConfig(level=logging.DEBUG, filename='/tmp/hacker-mode-settings.log', filemode='a',
                    format='%(asctime)s - %(levelname)s - %(message)s')

class HackerModeSettings:
    def __init__(self, root):
        logging.debug("Initializing HackerModeSettings")
        self.root = root
        self.is_muted = False
        self.is_dark_mode = True
        self.is_neon_theme = True  # Default to neon for bigpicture aesthetic
        self.config_frame = None
        self.wifi_action_lock = False
        self.running = True
        self.update_process = None
        self.image_references = []  # Store image references to prevent garbage collection
        self.setup_language()
        self.setup_colors()
        self.setup_window()
        self.setup_fonts()
        self.setup_ui()

    def setup_language(self):
        logging.debug("Setting up language")
        try:
            lang_code = locale.getlocale()[0] or os.getenv('LANG', 'en_US').split('.')[0]
            self.lang = lang_code.split('_')[0]
        except Exception as e:
            logging.error(f"Error setting language: {e}")
            self.lang = 'en'

        self.translations = {
            'en': {
                'title': "Hacker Mode Settings",
                'settings': "Settings",
                'hacker_menu': "HACKER MENU",
                'audio': "Audio",
                'increase_volume': "Increase Volume",
                'decrease_volume': "Decrease Volume",
                'toggle_mute': "Toggle Mute",
                'display': "Display",
                'increase_brightness': "Increase Brightness",
                'decrease_brightness': "Decrease Brightness",
                'toggle_theme': "Toggle Dark/Light Mode",
                'toggle_neon_theme': "Toggle Neon Theme",
                'change_resolution': "Change Resolution",
                'network': "Network",
                'wifi_settings': "Wi-Fi Settings",
                'connect_wifi': "Connect to Wi-Fi",
                'disconnect_wifi': "Disconnect Wi-Fi",
                'toggle_wifi': "Toggle Wi-Fi",
                'view_connections': "View Connections",
                'bluetooth': "Bluetooth",
                'power': "Power",
                'power_saving': "Power Saving",
                'balanced': "Balanced",
                'performance': "Performance",
                'screen_timeout': "Screen Timeout (minutes)",
                'battery_status': "Battery: {percent}% ({time})",
                'general': "General",
                'toggle_notifications': "Toggle Notifications",
                'change_language': "Change Language",
                'shortcut_info': "Close App Shortcut (Win + E)",
                'update_system': "Update System",
                'start_update': "Start Update",
                'cancel_update': "Cancel Update",
                'update_status': "Status: {status}",
                'update_output': "Update completed successfully:\n{output}",
                'update_failed': "Update failed:\n{error}",
                'update_script_missing': "Update script not found.",
                'update_canceled': "Update canceled.",
                'switch_plasma': "Switch to Plasma",
                'shutdown': "Shutdown",
                'restart': "Restart",
                'log_out': "Log Out",
                'restart_sway': "Restart Sway Session",
                'select_output': "Select Audio Output",
                'select_resolution': "Select Resolution",
                'select_language': "Select Language",
                'apply': "Apply",
                'close': "Close",
                'wifi_list': "Available Wi-Fi Networks",
                'connect': "Connect",
                'bluetooth_devices': "Bluetooth Devices",
                'scan': "Scan",
                'pair': "Pair",
                'no_networks': "No networks found",
                'connection_failed': "Connection failed: {error}",
                'connecting': "Connecting to {ssid}...",
                'scan_failed': "Scan failed: {error}",
                'pairing': "Pairing {device}...",
                'pairing_failed': "Pairing failed: {error}",
                'no_selection': "Please select an item",
                'wifi_toggle_failed': "Failed to toggle Wi-Fi: {error}",
                'wifi_toggle_success': "Wi-Fi turned {state}",
                'invalid_timeout': "Screen timeout must be a positive number",
                'shortcut_note': "Configure Win + E in Sway to close apps and reopen Hacker Mode",
                'mangohud': "MangoHUD",
                'toggle_mangohud': "Toggle MangoHUD",
                'gamemode': "GameMode",
                'toggle_gamemode': "Toggle GameMode",
                'vkbasalt': "VkBasalt",
                'toggle_vkbasalt': "Toggle VkBasalt",
                'system_info': "System Info",
                'cpu_usage': "CPU Usage: {usage}%",
                'memory_usage': "Memory Usage: {usage}%",
                'disk_usage': "Disk Usage: {usage}%",
                'updating': "Updating system...",
                'checking_updates': "Checking for updates...",
                'downloading': "Downloading updates...",
                'installing': "Installing updates...",
                'completed': "Update completed",
                'back_to_hacker_mode': "Back to Hacker Mode",
                'keyboard': "Keyboard",
                'change_layout': "Change Keyboard Layout",
                'key_repeat_rate': "Key Repeat Rate (ms)",
                'key_repeat_delay': "Key Repeat Delay (ms)",
                'touchpad': "Touchpad",
                'toggle_touchpad': "Toggle Touchpad",
                'touchpad_sensitivity': "Touchpad Sensitivity",
                'appearance': "Appearance",
                'change_wallpaper': "Change Wallpaper",
                'ui_scaling': "UI Scaling",
                'bar_transparency': "Bar Transparency (0.0-1.0)",
                'advanced': "Advanced",
                'clear_logs': "Clear System Logs",
                'restart_services': "Restart System Services",
                'check_health': "Check System Health",
                'invalid_value': "Invalid value",
                'success': "Success",
                'status_bar': "Last Action: {action}",
                'health_status': "Health: Disk {disk_status}, Memory {mem_status}",
                'no_battery': "No battery detected",
            },
            'pl': {
                'title': "Ustawienia Trybu Hakera",
                'settings': "Ustawienia",
                'hacker_menu': "MENU HAKERA",
                'audio': "Dźwięk",
                'increase_volume': "Zwiększ głośność",
                'decrease_volume': "Zmniejsz głośność",
                'toggle_mute': "Wycisz/Włącz dźwięk",
                'display': "Wyświetlacz",
                'increase_brightness': "Zwiększ jasność",
                'decrease_brightness': "Zmniejsz jasność",
                'toggle_theme': "Przełącz tryb ciemny/jasny",
                'toggle_neon_theme': "Przełącz tryb neonowy",
                'change_resolution': "Zmień rozdzielczość",
                'network': "Sieć",
                'wifi_settings': "Ustawienia Wi-Fi",
                'connect_wifi': "Połącz z Wi-Fi",
                'disconnect_wifi': "Rozłącz Wi-Fi",
                'toggle_wifi': "Włącz/Wyłącz Wi-Fi",
                'view_connections': "Pokaż połączenia",
                'bluetooth': "Bluetooth",
                'power': "Zasilanie",
                'power_saving': "Oszczędzanie energii",
                'balanced': "Zrównoważony",
                'performance': "Wydajność",
                'screen_timeout': "Czas wygaszania ekranu (minuty)",
                'battery_status': "Bateria: {percent}% ({time})",
                'general': "Ogólne",
                'toggle_notifications': "Włącz/Wyłącz powiadomienia",
                'change_language': "Zmień język",
                'shortcut_info': "Skrót do zamykania aplikacji (Win + E)",
                'update_system': "Aktualizuj system",
                'start_update': "Rozpocznij aktualizację",
                'cancel_update': "Anuluj aktualizację",
                'CECILIA': "Status: {status}",
                'update_output': "Aktualizacja zakończona pomyślnie:\n{output}",
                'update_failed': "Aktualizacja nieudana:\n{error}",
                'update_script_missing': "Skrypt aktualizacji nie znaleziony.",
                'update_canceled': "Aktualizacja anulowana.",
                'switch_plasma': "Przełącz na Plasma",
                'shutdown': "Wyłącz",
                'restart': "Uruchom ponownie",
                'log_out': "Wyloguj",
                'restart_sway': "Restartuj sesję Sway",
                'select_output': "Wybierz wyjście audio",
                'select_resolution': "Wybierz rozdzielczość",
                'select_language': "Wybierz język",
                'apply': "Zastosuj",
                'close': "Zamknij",
                'wifi_list': "Dostępne sieci Wi-Fi",
                'connect': "Połącz",
                'bluetooth_devices': "Urządzenia Bluetooth",
                'scan': "Skanuj",
                'pair': "Paruj",
                'no_networks': "Nie znaleziono sieci",
                'connection_failed': "Połączenie nieudane: {error}",
                'connecting': "Łączenie z {ssid}...",
                'scan_failed': "Skanowanie nieudane: {error}",
                'pairing': "Parowanie {device}...",
                'pairing_failed': "Parowanie nieudane: {error}",
                'no_selection': "Proszę wybrać element",
                'wifi_toggle_failed': "Nie udało się przełączyć Wi-Fi: {error}",
                'wifi_toggle_success': "Wi-Fi przełączone na {state}",
                'invalid_timeout': "Czas wygaszania ekranu musi być dodatnią liczbą",
                'shortcut_note': "Skonfiguruj Win + E w Sway, aby zamykać aplikacje i otwierać Tryb Hakera",
                'mangohud': "MangoHUD",
                'toggle_mangohud': "Włącz/Wyłącz MangoHUD",
                'gamemode': "Tryb Gry",
                'toggle_gamemode': "Włącz/Wyłącz Tryb Gry",
                'vkbasalt': "VkBasalt",
                'toggle_vkbasalt': "Włącz/Wyłącz VkBasalt",
                'system_info': "Informacje o Systemie",
                'cpu_usage': "Użycie CPU: {usage}%",
                'memory_usage': "Użycie pamięci: {usage}%",
                'disk_usage': "Użycie dysku: {usage}%",
                'updating': "Aktualizowanie systemu...",
                'checking_updates': "Sprawdzanie aktualizacji...",
                'downloading': "Pobieranie aktualizacji...",
                'installing': "Instalowanie aktualizacji...",
                'completed': "Aktualizacja zakończona",
                'back_to_hacker_mode': "Powrót do Trybu Hakera",
                'keyboard': "Klawiatura",
                'change_layout': "Zmień układ klawiatury",
                'key_repeat_rate': "Częstotliwość powtarzania klawiszy (ms)",
                'key_repeat_delay': "Opóźnienie powtarzania klawiszy (ms)",
                'touchpad': "Panel dotykowy",
                'toggle_touchpad': "Włącz/Wyłącz panel dotykowy",
                'touchpad_sensitivity': "Czułość panelu dotykowego",
                'appearance': "Wygląd",
                'change_wallpaper': "Zmień tapetę",
                'ui_scaling': "Skalowanie interfejsu",
                'bar_transparency': "Przezroczystość paska (0.0-1.0)",
                'advanced': "Zaawansowane",
                'clear_logs': "Wyczyść logi systemowe",
                'restart_services': "Restartuj usługi systemowe",
                'check_health': "Sprawdź stan systemu",
                'invalid_value': "Nieprawidłowa wartość",
                'success': "Sukces",
                'status_bar': "Ostatnia akcja: {action}",
                'health_status': "Stan: Dysk {disk_status}, Pamięć {mem_status}",
                'no_battery': "Nie wykryto baterii",
            }
        }
        if self.lang not in self.translations:
            self.lang = 'en'
        self._cached_translations = self.translations[self.lang]

    def get_text(self, key, **kwargs):
        return self._cached_translations.get(key, key).format(**kwargs)

    def setup_colors(self):
        logging.debug("Setting up colors")
        # Enhanced color scheme for a futuristic, neon "bigpicture" look
        self.bg_color = '#0D1B2A'  # Deep navy for a sleek background
        self.menu_color = '#1B263B'  # Darker slate for menus
        self.accent_color = '#00FF88' if self.is_neon_theme else '#FF4C29'  # Neon green or vibrant orange
        self.text_color = '#E0E1DD'  # Soft off-white for readability
        self.highlight_color = '#415A77'  # Muted teal for hover effects
        self.tab_bg_color = '#1B263B'  # Matches menu for cohesive tabs
        self.border_color = '#778DA9'  # Subtle gray-blue for borders
        self.neon_accent = '#00FF88'  # Bright neon green for emphasis
        self.progress_color = '#FF4C29'  # Orange for progress bars

    def setup_window(self):
        logging.debug("Setting up window")
        try:
            self.root.title(self.get_text('title'))
            self.root.attributes('-fullscreen', True)
            self.root.configure(bg=self.bg_color)
            self.root.bind('<Escape>', lambda e: self.on_closing())
            self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
            self.root.attributes('-topmost', False)
            self.root.wm_attributes('-type', 'normal')
            # Add a subtle fade-in animation for the window
            self.root.attributes('-alpha', 0.0)
            self.fade_in()
        except Exception as e:
            logging.error(f"Error setting up window: {e}")

    def fade_in(self):
        alpha = self.root.attributes('-alpha')
        if alpha < 1.0:
            alpha += 0.05
            self.root.attributes('-alpha', alpha)
            self.root.after(30, self.fade_in)

    def setup_fonts(self):
        logging.debug("Setting up fonts")
        try:
            # Larger, more modern fonts for bigpicture aesthetic
            self.title_font = tkfont.Font(family='Orbitron', size=20, weight='bold')  # Sci-fi font
            self.button_font = tkfont.Font(family='Orbitron', size=14)
            self.menu_font = tkfont.Font(family='Orbitron', size=12)
            self.label_font = tkfont.Font(family='Orbitron', size=13)
        except Exception as e:
            logging.error(f"Error setting up fonts: {e}")
            # Fallback to default fonts if Orbitron is unavailable
            self.title_font = tkfont.Font(family='Courier', size=20, weight='bold')
            self.button_font = tkfont.Font(family='Courier', size=14)
            self.menu_font = tkfont.Font(family='Courier', size=12)
            self.label_font = tkfont.Font(family='Courier', size=13)

    def on_closing(self):
        logging.debug("Closing application")
        self.running = False
        if self.update_process:
            self.cancel_update()
        # Fade out animation
        self.fade_out()

    def fade_out(self):
        alpha = self.root.attributes('-alpha')
        if alpha > 0.0:
            alpha -= 0.05
            self.root.attributes('-alpha', alpha)
            self.root.after(30, self.fade_out)
        else:
            self.root.destroy()
            sys.exit(0)

    def setup_ui(self):
        logging.debug("Setting up UI")
        try:
            self.setup_header()
            self.setup_settings_gui()
            self.setup_status_bar()
            self.setup_footer()
        except Exception as e:
            logging.error(f"Error setting up UI: {e}")

    def setup_header(self):
        logging.debug("Setting up header")
        logo_path = "/usr/share/HackerOS/ICONS/Hacker-Mode.png"
        header_frame = tk.Frame(self.root, bg=self.bg_color, bd=0)
        header_frame.place(relx=0.0, rely=0.0, relwidth=1.0, relheight=0.12)

        if os.path.exists(logo_path):
            try:
                logo_img = Image.open(logo_path).resize((100, 100), Image.LANCZOS)
                self.logo_photo = ImageTk.PhotoImage(logo_img)
                tk.Label(header_frame, image=self.logo_photo, bg=self.bg_color, bd=0).place(relx=0.95, rely=0.5, anchor='e')
                self.image_references.append(self.logo_photo)
            except Exception as e:
                logging.error(f"Error loading logo: {e}")

        title_label = tk.Label(
            header_frame, text=self.get_text('title'), bg=self.bg_color, fg=self.neon_accent,
            font=self.title_font, anchor='w', padx=20
        )
        title_label.place(relx=0.05, rely=0.5, anchor='w')

    def setup_status_bar(self):
        logging.debug("Setting up status bar")
        self.status_var = tk.StringVar(value=self.get_text('status_bar', action="Ready"))
        status_bar = tk.Label(
            self.root, textvariable=self.status_var, bg=self.menu_color, fg=self.text_color,
            font=self.label_font, anchor='w', padx=15, pady=10, relief='flat'
        )
        status_bar.place(relx=0.0, rely=0.92, relwidth=1.0, relheight=0.05, anchor='sw')

    def update_status(self, action):
        self.status_var.set(self.get_text('status_bar', action=action))

    def setup_footer(self):
        logging.debug("Setting up footer")
        menu_frame = tk.Frame(self.root, bg=self.menu_color, relief='raised', bd=1)
        menu_frame.place(relx=0.0, rely=0.97, anchor='sw', relwidth=1.0, relheight=0.08)

        self.hacker_button = tk.Button(
            menu_frame, text=self.get_text('hacker_menu'), command=self.show_hacker_menu,
            bg=self.menu_color, fg=self.neon_accent, font=self.button_font,
            activebackground=self.highlight_color, activeforeground=self.neon_accent,
            relief='flat', padx=20, pady=10, borderwidth=0
        )
        self.hacker_button.pack(side='left', padx=15, pady=5)
        self.hacker_button.bind("<Enter>", lambda e: self.hacker_button.config(bg=self.highlight_color, relief='raised'))
        self.hacker_button.bind("<Leave>", lambda e: self.hacker_button.config(bg=self.menu_color, relief='flat'))

        self.hacker_menu = tk.Menu(
            self.root, tearoff=0, bg=self.menu_color, fg=self.neon_accent, font=self.menu_font,
            activebackground=self.highlight_color, activeforeground=self.neon_accent, bd=1
        )
        self.hacker_menu.add_command(label=self.get_text('log_out'), command=self.logout)
        self.hacker_menu.add_command(label=self.get_text('shutdown'), command=self.shutdown)
        self.hacker_menu.add_command(label=self.get_text('restart'), command=self.restart)
        self.hacker_menu.add_command(label=self.get_text('switch_plasma'), command=self.switch_to_plasma)

        back_frame = tk.Frame(menu_frame, bg=self.menu_color)
        back_frame.pack(side='right', padx=15, pady=5)
        back_icon_path = "/usr/share/HackerOS/ICONS/back.png"
        if os.path.exists(back_icon_path):
            try:
                back_icon_img = Image.open(back_icon_path).resize((30, 30), Image.LANCZOS)
                back_icon_photo = ImageTk.PhotoImage(back_icon_img)
                tk.Label(back_frame, image=back_icon_photo, bg=self.menu_color).pack(side='left', padx=8)
                self.image_references.append(back_icon_photo)
            except Exception as e:
                logging.error(f"Error loading back icon: {e}")
        back_button = tk.Button(
            back_frame, text=self.get_text('back_to_hacker_mode'), command=self.back_to_hacker_mode,
            bg=self.menu_color, fg=self.neon_accent, font=self.button_font,
            activebackground=self.highlight_color, activeforeground=self.neon_accent,
            relief='flat', padx=20, pady=10, borderwidth=0
        )
        back_button.pack(side='left')
        back_button.bind("<Enter>", lambda e: back_frame.config(bg=self.highlight_color))
        back_button.bind("<Leave>", lambda e: back_frame.config(bg=self.menu_color))

    def show_hacker_menu(self):
        logging.debug("Showing hacker menu")
        try:
            self.hacker_menu.tk_popup(
                self.hacker_button.winfo_rootx(),
                self.hacker_button.winfo_rooty() - 200
            )
        except Exception as e:
            logging.error(f"Error showing hacker menu: {e}")

    def back_to_hacker_mode(self):
        logging.debug("Returning to Hacker Mode")
        try:
            hacker_mode_script = "/usr/share/HackerOS/Scripts/HackerOS-Apps/Hacker-Mode/Hacker-Mode.py"
            if not os.path.exists(hacker_mode_script):
                logging.error(f"Hacker Mode script not found at {hacker_mode_script}")
                messagebox.showerror(self.get_text('title'), f"Hacker Mode script not found at {hacker_mode_script}")
                return

            self.running = False
            self.fade_out()

            env = os.environ.copy()
            env['XDG_SESSION_TYPE'] = 'wayland'
            subprocess.Popen(
                ["python3", hacker_mode_script],
                env=env,
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            logging.debug("Hacker Mode launched")
        except Exception as e:
            logging.error(f"Error launching Hacker Mode: {e}")
            messagebox.showerror(self.get_text('title'), f"Error launching Hacker Mode: {e}")

    def setup_settings_gui(self):
        logging.debug("Setting up settings GUI")
        try:
            settings_frame = tk.Frame(self.root, bg=self.bg_color, bd=3, relief='flat', highlightbackground=self.border_color, highlightthickness=1)
            settings_frame.place(relx=0.5, rely=0.5, anchor='center', relwidth=0.9, relheight=0.78)

            style = ttk.Style()
            style.configure("TNotebook", background=self.bg_color, borderwidth=0)
            style.configure("TNotebook.Tab", background=self.tab_bg_color, foreground=self.text_color, font=self.button_font, padding=[20, 15], borderwidth=1, relief='flat')
            style.map("TNotebook.Tab", background=[("selected", self.highlight_color)], foreground=[("selected", self.neon_accent)])

            self.notebook = ttk.Notebook(settings_frame)
            self.notebook.pack(pady=20, padx=20, fill='both', expand=True)
            self.notebook.bind("<<NotebookTabChanged>>", self.on_tab_changed)

            def add_button(parent, text, command, tooltip_key=None, icon=None):
                btn_frame = tk.Frame(parent, bg=self.bg_color)
                btn_frame.pack(pady=10, padx=15, fill='x')
                if icon and os.path.exists(icon):
                    try:
                        icon_img = Image.open(icon).resize((30, 30), Image.LANCZOS)
                        icon_photo = ImageTk.PhotoImage(icon_img)
                        tk.Label(btn_frame, image=icon_photo, bg=self.bg_color).pack(side='left', padx=8)
                        btn_frame.image = icon_photo
                        self.image_references.append(icon_photo)
                    except Exception as e:
                        logging.error(f"Error loading icon {icon}: {e}")
                btn = tk.Button(
                    btn_frame, text=text, command=lambda: self.button_command(command, text),
                    bg=self.menu_color, fg=self.text_color, font=self.button_font,
                    relief='flat', padx=15, pady=10, borderwidth=0
                )
                btn.pack(side='left', fill='x', expand=True)
                btn.bind("<Enter>", lambda e: btn.config(bg=self.highlight_color, relief='raised'))
                btn.bind("<Leave>", lambda e: btn.config(bg=self.menu_color, relief='flat'))
                if tooltip_key:
                    btn.bind("<Enter>", lambda e, t=self.get_text(tooltip_key): self.show_tooltip(btn, t), add='+')
                    btn.bind("<Leave>", lambda e: self.hide_tooltip(), add='+')
                return btn

            def add_label(parent, text):
                return tk.Label(parent, text=text, bg=self.bg_color, fg=self.text_color, font=self.label_font, pady=8)

            def add_entry(parent, textvariable):
                return tk.Entry(
                    parent, textvariable=textvariable, bg=self.menu_color, fg=self.text_color,
                    font=self.label_font, insertbackground=self.neon_accent, relief='flat', bd=1
                )

            # Audio Tab
            audio_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(audio_frame, text=self.get_text('audio'))
            add_button(audio_frame, self.get_text('increase_volume'), self.increase_volume, 'tooltip_increase_volume', "/usr/share/HackerOS/ICONS/audio-up.png")
            add_button(audio_frame, self.get_text('decrease_volume'), self.decrease_volume, 'tooltip_decrease_volume', "/usr/share/HackerOS/ICONS/audio-down.png")
            add_button(audio_frame, self.get_text('toggle_mute'), self.toggle_mute, 'tooltip_toggle_mute', "/usr/share/HackerOS/ICONS/mute.png")
            add_label(audio_frame, self.get_text('select_output')).pack(pady=8)
            for output in self.get_audio_outputs():
                add_button(audio_frame, output, lambda o=output: self.set_audio_output(o))

            # Display Tab
            display_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(display_frame, text=self.get_text('display'))
            add_button(display_frame, self.get_text('increase_brightness'), self.increase_brightness, 'tooltip_increase_brightness', "/usr/share/HackerOS/ICONS/brightness-up.png")
            add_button(display_frame, self.get_text('decrease_brightness'), self.decrease_brightness, 'tooltip_decrease_brightness', "/usr/share/HackerOS/ICONS/brightness-down.png")
            add_button(display_frame, self.get_text('toggle_theme'), self.toggle_theme, 'tooltip_toggle_theme')
            add_button(display_frame, self.get_text('toggle_neon_theme'), self.toggle_neon_theme)
            add_label(display_frame, self.get_text('select_resolution')).pack(pady=8)
            for res in self.get_resolutions():
                add_button(display_frame, res, lambda r=res: self.set_resolution(r))

            # Network Tab with Wi-Fi Icon
            network_frame = tk.Frame(self.notebook, bg=self.bg_color)
            network_tab_frame = tk.Frame(self.notebook, bg=self.tab_bg_color)
            wifi_icon_path = "/usr/share/HackerOS/ICONS/wifi.png"
            if os.path.exists(wifi_icon_path):
                try:
                    wifi_icon_img = Image.open(wifi_icon_path).resize((30, 30), Image.LANCZOS)
                    wifi_icon_photo = ImageTk.PhotoImage(wifi_icon_img)
                    tk.Label(network_tab_frame, image=wifi_icon_photo, bg=self.tab_bg_color).pack(side='left', padx=5)
                    self.image_references.append(wifi_icon_photo)
                except Exception as e:
                    logging.error(f"Error loading Wi-Fi icon: {e}")
            tk.Label(network_tab_frame, text=self.get_text('network'), bg=self.tab_bg_color, fg=self.neon_accent, font=self.button_font).pack(side='left', padx=5)
            self.notebook.add(network_frame, text='')
            self.notebook.tab(network_frame, compound='left', image='')
            network_tab_frame.update_idletasks()
            self.notebook.tab(network_frame, text='', padding=[20, 15])
            add_button(network_frame, self.get_text('wifi_settings'), self.show_wifi_settings, icon="/usr/share/HackerOS/ICONS/wifi.png")
            add_button(network_frame, self.get_text('connect_wifi'), self.show_wifi_networks)
            add_button(network_frame, self.get_text('disconnect_wifi'), self.disconnect_wifi)
            add_button(network_frame, self.get_text('view_connections'), self.view_connections)
            add_button(network_frame, self.get_text('toggle_wifi'), self.toggle_wifi, 'tooltip_toggle_wifi')
            add_button(network_frame, self.get_text('bluetooth'), self.show_bluetooth, icon="/usr/share/HackerOS/ICONS/bluetooth.png")

            # Power Tab
            power_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(power_frame, text=self.get_text('power'))
            add_button(power_frame, self.get_text('power_saving'), lambda: self.set_power_profile("power-saver"))
            add_button(power_frame, self.get_text('balanced'), lambda: self.set_power_profile("balanced"))
            add_button(power_frame, self.get_text('performance'), lambda: self.set_power_profile("performance"))
            add_label(power_frame, self.get_text('screen_timeout')).pack(pady=8)
            self.timeout_var = tk.StringVar(value="5")
            add_entry(power_frame, self.timeout_var).pack(pady=8, padx=15)
            add_button(power_frame, self.get_text('apply'), self.apply_timeout)
            self.battery_label = add_label(power_frame, self.get_text('no_battery'))
            self.battery_label.pack(pady=8)
            self.update_battery_status()

            # Gaming Tab
            gaming_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(gaming_frame, text="Gaming")
            add_button(gaming_frame, self.get_text('toggle_mangohud'), self.toggle_mangohud, 'tooltip_toggle_mangohud')
            add_button(gaming_frame, self.get_text('toggle_gamemode'), self.toggle_gamemode, 'tooltip_toggle_gamemode')
            add_button(gaming_frame, self.get_text('toggle_vkbasalt'), self.toggle_vkbasalt, 'tooltip_toggle_vkbasalt')

            # System Update Tab
            update_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(update_frame, text=self.get_text('update_system'))
            self.update_status_var = tk.StringVar(value=self.get_text('update_status', status="Idle"))
            add_label(update_frame, "").pack()  # Spacer
            tk.Label(update_frame, textvariable=self.update_status_var, bg=self.bg_color, fg=self.neon_accent, font=self.label_font).pack(pady=8)
            button_frame = tk.Frame(update_frame, bg=self.bg_color)
            button_frame.pack(fill='x', padx=15)
            self.start_update_btn = add_button(button_frame, self.get_text('start_update'), self.show_update_system)
            self.start_update_btn.pack(side='left', padx=8)
            self.cancel_update_btn = add_button(button_frame, self.get_text('cancel_update'), self.cancel_update)
            self.cancel_update_btn.pack(side='left', padx=8)
            self.cancel_update_btn.config(state='disabled')
            self.update_output = scrolledtext.ScrolledText(
                update_frame, height=12, bg=self.menu_color, fg=self.text_color,
                font=self.label_font, insertbackground=self.neon_accent, relief='flat'
            )
            self.update_output.pack(pady=10, padx=15, fill='both', expand=True)
            self.progress_var = tk.DoubleVar()
            self.progress_bar = ttk.Progressbar(update_frame, variable=self.progress_var, maximum=100, style='TProgressbar')
            self.progress_bar.pack(pady=8, fill='x', padx=15)
            style.configure("TProgressbar", background=self.progress_color, troughcolor=self.menu_color, borderwidth=0)
            self.progress_bar.bind("<Configure>", self.pulse_progress)

            # General Tab
            general_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(general_frame, text=self.get_text('general'))
            add_button(general_frame, self.get_text('toggle_notifications'), self.toggle_notifications, 'tooltip_toggle_notifications')
            add_label(general_frame, self.get_text('select_language')).pack(pady=8)
            for lang in self.translations.keys():
                add_button(general_frame, lang, lambda l=lang: self.change_language(l))
            add_button(general_frame, self.get_text('shortcut_info'), self.show_shortcut_info)

            # System Info Tab
            system_info_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(system_info_frame, text=self.get_text('system_info'))
            self.cpu_label = add_label(system_info_frame, self.get_text('cpu_usage', usage=0))
            self.cpu_label.pack(pady=8)
            self.memory_label = add_label(system_info_frame, self.get_text('memory_usage', usage=0))
            self.memory_label.pack(pady=8)
            self.disk_label = add_label(system_info_frame, self.get_text('disk_usage', usage=0))
            self.disk_label.pack(pady=8)
            self.update_system_info()

            # Keyboard Tab
            keyboard_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(keyboard_frame, text=self.get_text('keyboard'))
            add_label(keyboard_frame, self.get_text('change_layout')).pack(pady=8)
            for layout in ['us', 'pl']:
                add_button(keyboard_frame, layout.upper(), lambda l=layout: self.set_keyboard_layout(l))
            add_label(keyboard_frame, self.get_text('key_repeat_rate')).pack(pady=8)
            self.repeat_rate_var = tk.StringVar(value="300")
            add_entry(keyboard_frame, self.repeat_rate_var).pack(pady=8, padx=15)
            add_label(keyboard_frame, self.get_text('key_repeat_delay')).pack(pady=8)
            self.repeat_delay_var = tk.StringVar(value="600")
            add_entry(keyboard_frame, self.repeat_delay_var).pack(pady=8, padx=15)
            add_button(keyboard_frame, self.get_text('apply'), self.apply_keyboard_settings)

            # Touchpad Tab
            touchpad_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(touchpad_frame, text=self.get_text('touchpad'))
            add_button(touchpad_frame, self.get_text('toggle_touchpad'), self.toggle_touchpad, 'tooltip_toggle_touchpad')
            add_label(touchpad_frame, self.get_text('touchpad_sensitivity')).pack(pady=8)
            self.sensitivity_var = tk.StringVar(value="1.0")
            add_entry(touchpad_frame, self.sensitivity_var).pack(pady=8, padx=15)
            add_button(touchpad_frame, self.get_text('apply'), self.apply_touchpad_sensitivity)

            # Appearance Tab
            appearance_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(appearance_frame, text=self.get_text('appearance'))
            add_label(appearance_frame, self.get_text('change_wallpaper')).pack(pady=8)
            wallpapers = self.get_wallpapers()
            for wp in wallpapers:
                add_button(appearance_frame, wp, lambda w=wp: self.set_wallpaper(w))
            add_label(appearance_frame, self.get_text('ui_scaling')).pack(pady=8)
            self.scaling_var = tk.StringVar(value="1.0")
            add_entry(appearance_frame, self.scaling_var).pack(pady=8, padx=15)
            add_button(appearance_frame, self.get_text('apply'), self.apply_ui_scaling)
            add_label(appearance_frame, self.get_text('bar_transparency')).pack(pady=8)
            self.transparency_var = tk.StringVar(value="0.5")
            add_entry(appearance_frame, self.transparency_var).pack(pady=8, padx=15)
            add_button(appearance_frame, self.get_text('apply'), self.apply_bar_transparency)

            # Advanced Tab
            advanced_frame = tk.Frame(self.notebook, bg=self.bg_color)
            self.notebook.add(advanced_frame, text=self.get_text('advanced'))
            add_button(advanced_frame, self.get_text('clear_logs'), self.clear_logs, 'tooltip_clear_logs')
            add_button(advanced_frame, self.get_text('restart_services'), self.restart_services, 'tooltip_restart_services')
            add_button(advanced_frame, self.get_text('check_health'), self.check_health)

        except Exception as e:
            logging.error(f"Error setting up settings GUI: {e}")

    def show_tooltip(self, widget, text):
        if hasattr(self, 'tooltip_window'):
            self.hide_tooltip()
        x = widget.winfo_rootx() + 30
        y = widget.winfo_rooty() + widget.winfo_height() + 10
        self.tooltip_window = tk.Toplevel(self.root)
        self.tooltip_window.wm_overrideredirect(True)
        self.tooltip_window.wm_geometry(f"+{x}+{y}")
        label = tk.Label(
            self.tooltip_window, text=text, bg=self.menu_color, fg=self.neon_accent,
            font=self.menu_font, padx=8, pady=4, relief='solid', borderwidth=1
        )
        label.pack()

    def hide_tooltip(self):
        if hasattr(self, 'tooltip_window'):
            self.tooltip_window.destroy()
            del self.tooltip_window

    def on_tab_changed(self, event):
        selected_tab = self.notebook.select()
        tab_text = self.notebook.tab(selected_tab, "text") or self.get_text('network')
        self.update_status(f"Switched to {tab_text} tab")
        def fade(step=0):
            if step > 10:
                return
            r = int(self.tab_bg_color[1:3], 16)
            g = int(self.tab_bg_color[3:5], 16)
            b = int(self.tab_bg_color[5:7], 16)
            r += (int(self.highlight_color[1:3], 16) - r) * step // 10
            g += (int(self.highlight_color[3:5], 16) - g) * step // 10
            b += (int(self.highlight_color[5:7], 16) - b) * step // 10
            temp_color = f"#{r:02x}{g:02x}{b:02x}"
            style = ttk.Style()
            style.configure("TNotebook.Tab", background=temp_color)
            self.root.after(50, lambda: fade(step + 1))
        fade()

    def button_command(self, command, action_text):
        command()
        self.update_status(action_text)

    def pulse_progress(self, event):
        if self.progress_var.get() < 100 and self.update_process:
            current = self.progress_var.get()
            self.progress_var.set(current + 0.5 if current < 99 else 99)
            self.root.after(200, lambda: self.pulse_progress(event))

    def apply_timeout(self):
        logging.debug("Applying screen timeout")
        try:
            timeout = self.timeout_var.get()
            if not timeout.isdigit() or int(timeout) <= 0:
                messagebox.showerror(self.get_text('title'), self.get_text('invalid_timeout'))
                return
            subprocess.run(["swaymsg", f"output * dpms {timeout}"], check=False)
            self.update_status("Screen timeout applied")
        except Exception as e:
            logging.error(f"Error applying timeout: {e}")

    def show_update_system(self):
        logging.debug("Showing system update")
        script_path = "/usr/share/HackerOS/Scripts/Bin/Hacker-Mode-Update.sh"
        if not os.path.exists(script_path):
            self.update_output.insert(tk.END, self.get_text('update_script_missing') + "\n")
            logging.error(f"Update script not found at {script_path}")
            return

        self.update_output.delete(1.0, tk.END)
        self.progress_var.set(0)
        self.update_status_var.set(self.get_text('update_status', status=self.get_text('checking_updates')))
        self.start_update_btn.config(state='disabled')
        self.cancel_update_btn.config(state='normal')

        def run_update():
            try:
                self.update_process = subprocess.Popen(
                    [script_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1, universal_newlines=True
                )
                total_packages = 0
                processed_packages = 0
                phase = "checking"

                while True:
                    line = self.update_process.stdout.readline()
                    if not line and self.update_process.poll() is not None:
                        break
                    if not line:
                        continue
                    line = line.strip()
                    self.update_output.insert(tk.END, line + "\n")
                    self.update_output.see(tk.END)
                    self.root.update()

                    if "downloading" in line.lower():
                        phase = "downloading"
                        self.update_status_var.set(self.get_text('update_status', status=self.get_text('downloading')))
                    elif "installing" in line.lower():
                        phase = "installing"
                        self.update_status_var.set(self.get_text('update_status', status=self.get_text('installing')))

                    total_match = re.search(r'Found (\d+) updates', line, re.IGNORECASE)
                    if total_match:
                        total_packages = int(total_match.group(1))

                    progress_match = re.search(r'Progress: (\d+)%', line)
                    if progress_match:
                        progress = int(progress_match.group(1))
                        self.progress_var.set(progress)
                    elif total_packages > 0 and "Updating package" in line:
                        processed_packages += 1
                        progress = (processed_packages / total_packages) * 100
                        self.progress_var.set(min(progress, 100))

                stderr = self.update_process.stderr.read()
                if stderr:
                    self.update_output.insert(tk.END, stderr + "\n")
                    self.update_output.see(tk.END)

                if self.update_process.returncode == 0:
                    self.update_status_var.set(self.get_text('update_status', status=self.get_text('completed')))
                    self.update_output.insert(tk.END, self.get_text('update_output', output="Done") + "\n")
                else:
                    self.update_output.insert(tk.END, self.get_text('update_failed', error=stderr) + "\n")
                logging.debug(f"Update script completed with return code {self.update_process.returncode}")
            except Exception as e:
                self.update_output.insert(tk.END, self.get_text('update_failed', error=str(e)) + "\n")
                logging.error(f"Error running update script: {e}")
            finally:
                self.start_update_btn.config(state='normal')
                self.cancel_update_btn.config(state='disabled')
                self.update_process = None
                self.update_status("System update finished")

        threading.Thread(target=run_update, daemon=True).start()

    def cancel_update(self):
        logging.debug("Canceling system update")
        if self.update_process:
            self.update_process.terminate()
            try:
                self.update_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.update_process.kill()
            self.update_output.insert(tk.END, self.get_text('update_canceled') + "\n")
            self.update_output.see(tk.END)
            self.update_status_var.set(self.get_text('update_status', status="Canceled"))
            self.start_update_btn.config(state='normal')
            self.cancel_update_btn.config(state='disabled')
            self.update_process = None
            self.update_status("System update canceled")

    def get_audio_outputs(self):
        logging.debug("Getting audio outputs")
        try:
            result = subprocess.run(["pactl", "list", "sinks", "short"], capture_output=True, text=True, check=False)
            outputs = [line.split()[1] for line in result.stdout.strip().split("\n") if line]
            return outputs or ["Default"]
        except Exception:
            return ["Default"]

    def set_delve into the technical details of the audio system, explaining how it works and what specific components are involved in producing sound on a computer.

    def set_audio_output(self, output):
        logging.debug(f"Setting audio output to {output}")
        subprocess.run(["pactl", "set-default-sink", output], check=False)

    def get_resolutions(self):
        logging.debug("Getting resolutions")
        try:
            result = subprocess.run(["wlr-randr"], capture_output=True, text=True, check=False)
            resolutions = [line.strip().split()[0] for line in result.stdout.split("\n") if "x" in line and "@" in line]
            return resolutions or ["Default"]
        except Exception:
            return ["Default"]

    def set_resolution(self, resolution):
        logging.debug(f"Setting resolution to {resolution}")
        subprocess.run(["wlr-randr", "--output", "*", "--mode", resolution], check=False)

    def change_language(self, lang):
        logging.debug(f"Changing language to {lang}")
        self.lang = lang
        self._cached_translations = self.translations.get(lang, self.translations['en'])
        self.root.title(self.get_text('title'))
        self.setup_ui()

    def show_shortcut_info(self):
        logging.debug("Showing shortcut info")
        messagebox.showinfo(self.get_text('shortcut_info'), self.get_text('shortcut_note'))

    def clear_config_frame(self):
        if self.config_frame is not None:
            self.config_frame.destroy()
        self.config_frame = tk.Frame(self.root, bg=self.menu_color, bd=2, relief='flat', highlightbackground=self.border_color, highlightthickness=1)
        self.config_frame.place(relx=0.75, rely=0.5, anchor='center', relwidth=0.35, relheight=0.65)

    def show_wifi_settings(self):
        logging.debug("Showing Wi-Fi settings")
        self.clear_config_frame()
        tk.Label(self.config_frame, text=self.get_text('wifi_list'), bg=self.menu_color, fg=self.neon_accent, font=self.label_font).pack(pady=8)
        try:
            result = subprocess.run(["nmcli", "-t", "-f", "SSID,SIGNAL", "dev", "wifi"], capture_output=True, text=True, check=False)
            networks = [line.split(":") for line in result.stdout.strip().split("\n") if line]
            if not networks:
                tk.Label(self.config_frame, text=self.get_text('no_networks'), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
                return

            wifi_listbox = tk.Listbox(self.config_frame, bg=self.menu_color, fg=self.text_color, font=self.label_font, height=8, relief='flat')
            wifi_listbox.pack(pady=8, padx=10, fill='both', expand=True)
            for ssid, signal in networks:
                wifi_listbox.insert(tk.END, f"{ssid} ({signal}%)")

            tk.Label(self.config_frame, text="Password (if required):", bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
            password_entry = tk.Entry(self.config_frame, bg=self.menu_color, fg=self.text_color, show="*", font=self.label_font, insertbackground=self.neon_accent)
            password_entry.pack(pady=8, padx=10)
            btn = tk.Button(
                self.config_frame, text=self.get_text('connect'), command=lambda: self.connect_wifi_from_list(wifi_listbox, password_entry.get()),
                bg=self.menu_color, fg=self.neon_accent, font=self.button_font, relief='flat', padx=15
            )
            btn.pack(pady=8)
            btn.bind("<Enter>", lambda e: btn.config(bg=self.highlight_color, relief='raised'))
            btn.bind("<Leave>", lambda e: btn.config(bg=self.menu_color, relief='flat'))
        except Exception as e:
            logging.error(f"Error showing Wi-Fi settings: {e}")

    def connect_wifi_from_list(self, listbox, password):
        logging.debug("Connecting to selected Wi-Fi")
        try:
            selection = listbox.curselection()
            if not selection:
                tk.Label(self.config_frame, text=self.get_text('no_selection'), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
                return
            selected = listbox.get(selection)
            ssid = selected.split(" (")[0]
            cmd = ["nmcli", "dev", "wifi", "connect", ssid]
            if password:
                cmd.extend(["password", password])
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            tk.Label(self.config_frame, text=self.get_text('connecting' if result.returncode == 0 else 'connection_failed', ssid=ssid, error=result.stderr), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
            self.update_status(f"Connected to Wi-Fi {ssid}")
        except Exception as e:
            logging.error(f"Error connecting to Wi-Fi: {e}")
            tk.Label(self.config_frame, text=self.get_text('connection_failed', error=str(e)), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)

    def show_wifi_networks(self):
        logging.debug("Showing Wi-Fi networks")
        self.clear_config_frame()
        tk.Label(self.config_frame, text=self.get_text('wifi_list'), bg=self.menu_color, fg=self.neon_accent, font=self.label_font).pack(pady=8)
        try:
            result = subprocess.run(["nmcli", "-t", "-f", "SSID,SIGNAL", "dev", "wifi"], capture_output=True, text=True, check=False)
            networks = [line.split(":") for line in result.stdout.strip().split("\n") if line]
            if not networks:
                tk.Label(self.config_frame, text=self.get_text('no_networks'), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
                return
            for ssid, signal in networks:
                btn = tk.Button(
                    self.config_frame, text=f"{ssid} ({signal}%)", command=lambda s=ssid: self.connect_wifi(s),
                    bg=self.menu_color, fg=self.text_color, font=self.button_font, relief='flat'
                )
                btn.pack(pady=4, fill='x', padx=10)
                btn.bind("<Enter>", lambda e, b=btn: b.config(bg=self.highlight_color, relief='raised'))
                btn.bind("<Leave>", lambda e, b=btn: b.config(bg=self.menu_color, relief='flat'))
        except Exception as e:
            logging.error(f"Error showing Wi-Fi networks: {e}")

    def disconnect_wifi(self):
        logging.debug("Disconnecting Wi-Fi")
        try:
            result = subprocess.run(["nmcli", "con", "down", "default"], capture_output=True, text=True, check=False)
            if result.returncode == 0:
                self.update_status("Wi-Fi disconnected")
            else:
                messagebox.showerror(self.get_text('title'), "Failed to disconnect Wi-Fi")
        except Exception as e:
            logging.error(f"Error disconnecting Wi-Fi: {e}")

    def view_connections(self):
        logging.debug("Viewing Wi-Fi connections")
        self.clear_config_frame()
        tk.Label(self.config_frame, text="Active Connections:", bg=self.menu_color, fg=self.neon_accent, font=self.label_font).pack(pady=8)
        try:
            result = subprocess.run(["nmcli", "-t", "-f", "NAME,TYPE,STATE", "con", "show", "--active"], capture_output=True, text=True, check=False)
            connections = [line.split(":") for line in result.stdout.strip().split("\n") if line]
            if not connections:
                tk.Label(self.config_frame, text="No active connections", bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
                return
            for name, type_, state in connections:
                tk.Label(self.config_frame, text=f"{name} ({type_}: {state})", bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=4)
        except Exception as e:
            logging.error(f"Error viewing connections: {e}")

    def connect_wifi(self, ssid):
        logging.debug(f"Connecting to Wi-Fi {ssid}")
        try:
            result = subprocess.run(["nmcli", "dev", "wifi", "connect", ssid], capture_output=True, text=True, check=False)
            tk.Label(self.config_frame, text=self.get_text('connecting' if result.returncode == 0 else 'connection_failed', ssid=ssid, error=result.stderr), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
        except Exception as e:
            logging.error(f"Error connecting to Wi-Fi {ssid}: {e}")

    def toggle_wifi(self):
        logging.debug("Toggling Wi-Fi")
        if self.wifi_action_lock:
            return
        self.wifi_action_lock = True
        try:
            self.clear_config_frame()
            self.wifi_enabled = not getattr(self, 'wifi_enabled', True)
            action = "on" if self.wifi_enabled else "off"
            result = subprocess.run(["nmcli", "radio", "wifi", action], capture_output=True, text=True, check=False)
            tk.Label(self.config_frame, text=self.get_text('wifi_toggle_success' if result.returncode == 0 else 'wifi_toggle_failed', state=action, error=result.stderr), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
        except Exception as e:
            logging.error(f"Error toggling Wi-Fi: {e}")
        finally:
            self.wifi_action_lock = False

    def show_bluetooth(self):
        logging.debug("Showing Bluetooth")
        self.clear_config_frame()
        tk.Label(self.config_frame, text=self.get_text('bluetooth_devices'), bg=self.menu_color, fg=self.neon_accent, font=self.label_font).pack(pady=8)
        btn1 = tk.Button(
            self.config_frame, text=self.get_text('scan'), command=self.scan_bluetooth,
            bg=self.menu_color, fg=self.neon_accent, font=self.button_font, relief='flat'
        )
        btn1.pack(pady=8, fill='x', padx=10)
        btn1.bind("<Enter>", lambda e: btn1.config(bg=self.highlight_color, relief='raised'))
        btn1.bind("<Leave>", lambda e: btn1.config(bg=self.menu_color, relief='flat'))
        self.bluetooth_listbox = tk.Listbox(self.config_frame, bg=self.menu_color, fg=self.text_color, font=self.label_font, height=6, relief='flat')
        self.bluetooth_listbox.pack(pady=8, padx=10, fill='both', expand=True)
        btn2 = tk.Button(
            self.config_frame, text=self.get_text('pair'), command=self.pair_bluetooth,
            bg=self.menu_color, fg=self.neon_accent, font=self.button_font, relief='flat'
        )
        btn2.pack(pady=8, fill='x', padx=10)
        btn2.bind("<Enter>", lambda e: btn2.config(bg=self.highlight_color, relief='raised'))
        btn2.bind("<Leave>", lambda e: btn2.config(bg=self.menu_color, relief='flat'))

    def scan_bluetooth(self):
        logging.debug("Scanning Bluetooth devices")
        try:
            subprocess.run(["bluetoothctl", "power", "on"], check=False)
            subprocess.run(["bluetoothctl", "scan", "on"], check=False)
            result = subprocess.run(["bluetoothctl", "devices"], capture_output=True, text=True, check=False)
            subprocess.run(["bluetoothctl", "scan", "off"], check=False)
            devices = [line for line in result.stdout.strip().split("\n") if line.startswith("Device")]
            self.bluetooth_listbox.delete(0, tk. END)
            if not devices:
                tk.Label(self.config_frame, text="No devices found", bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
            for device in devices:
                self.bluetooth_listbox.insert(tk.END, device)
            self.update_status("Bluetooth scan completed")
        except Exception as e:
            logging.error(f"Error scanning Bluetooth: {e}")

    def pair_bluetooth(self):
        logging.debug("Pairing Bluetooth device")
        try:
            selection = self.bluetooth_listbox.curselection()
            if not selection:
                tk.Label(self.config_frame, text=self.get_text('no_selection'), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
                return
            selected = self.bluetooth_listbox.get(selection)
            device_id = selected.split()[1]
            tk.Label(self.config_frame, text=self.get_text('pairing', device=device_id), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
            pair_result = subprocess.run(["bluetoothctl", "pair", device_id], capture_output=True, text=True, check=False)
            if pair_result.returncode != 0:
                tk.Label(self.config_frame, text=self.get_text('pairing_failed', error=pair_result.stderr), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
                return
            connect_result = subprocess.run(["bluetoothctl", "connect", device_id], capture_output=True, text=True, check=False)
            if connect_result.returncode != 0:
                tk.Label(self.config_frame, text=self.get_text('pairing_failed', error=connect_result.stderr), bg=self.menu_color, fg=self.text_color, font=self.label_font).pack(pady=8)
            self.update_status(f"Paired Bluetooth device {device_id}")
        except Exception as e:
            logging.error(f"Error pairing Bluetooth: {e}")

    def increase_volume(self):
        logging.debug("Increasing volume")
        subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"], check=False)
        self.is_muted = False

    def decrease_volume(self):
        logging.debug("Decreasing volume")
        subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"], check=False)
        self.is_muted = False

    def toggle_mute(self):
        logging.debug("Toggling mute")
        self.is_muted = not self.is_muted
        subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"], check=False)

    def increase_brightness(self):
        logging.debug("Increasing brightness")
        subprocess.run(["brightnessctl", "set", "+5%"], check=False)

    def decrease_brightness(self):
        logging.debug("Decreasing brightness")
        subprocess.run(["brightnessctl", "set", "5%-"], check=False)

    def toggle_theme(self):
        logging.debug("Toggling theme")
        try:
            self.is_dark_mode = not self.is_dark_mode
            theme = "dark" if self.is_dark_mode else "light"
            config_path = f"/home/{getpass.getuser()}/.config/sway/config"
            if os.path.exists(config_path):
 weddings                with open(config_path, "r") as f:
                    config = f.read()
                new_config = config.replace(
                    f"set $theme {'light' if self.is_dark_mode else 'dark'}",
                    f"set $theme {theme}"
                )
                with open(config_path, "w") as f:
                    f.write(new_config)
                subprocess.run(["swaymsg", "reload"], check=False)
            self.setup_colors()
            self.setup_ui()
        except Exception as e:
            logging.error(f"Error toggling theme: {e}")

    def toggle_neon_theme(self):
        logging.debug("Toggling neon theme")
        self.is_neon_theme = not self.is_neon_theme
        self.setup_colors()
        self.setup_ui()

    def toggle_notifications(self):
        logging.debug("Toggling notifications")
        self.notifications_enabled = not getattr(self, 'notifications_enabled', True)
        if subprocess.run(["which", "makoctl"], capture_output=True).returncode == 0:
            subprocess.run(["makoctl", "set-mode", "do-not-disturb" if not self.notifications_enabled else "default"], check=False)

    def set_power_profile(self, profile):
        logging.debug(f"Setting power profile to {profile}")
        subprocess.run(["powerprofilesctl", "set", profile], check=False)

    def toggle_mangohud(self):
        logging.debug("Toggling MangoHUD")
        self.mangohud_enabled = not getattr(self, 'mangohud_enabled', False)
        try:
            with open(f"/home/{getpass.getuser()}/.config/MangoHud/MangoHud.conf", "w") as f:
                f.write(f"toggle_hud={1 if self.mangohud_enabled else 0}\n")
        except Exception as e:
            logging.error(f"Error toggling MangoHUD: {e}")

    def toggle_gamemode(self):
        logging.debug("Toggling GameMode")
        self.gamemode_enabled = not getattr(self, 'gamemode_enabled', False)
        messagebox.showinfo(self.get_text('gamemode'), f"GameMode {'enabled' if self.gamemode_enabled else 'disabled'}")

    def toggle_vkbasalt(self):
        logging.debug("Toggling VkBasalt")
        self.vkbasalt_enabled = not getattr(self, 'vkbasalt_enabled', False)
        try:
            with open(f"/home/{getpass.getuser()}/.config/vkBasalt/vkBasalt.conf", "w") as f:
                f.write(f"enable={1 if self.vkbasalt_enabled else 0}\n")
        except Exception as e:
            logging.error(f"Error toggling VkBasalt: {e}")

    def update_system_info(self):
        if not self.running:
            return
        logging.debug("Updating system info")
        try:
            cpu_usage = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            self.cpu_label.config(text=self.get_text('cpu_usage', usage=round(cpu_usage, 1)))
            self.memory_label.config(text=self.get_text('memory_usage', usage=round(memory.percent, 1)))
            self.disk_label.config(text=self.get_text('disk_usage', usage=round(disk.percent, 1)))
            if self.running:
                self.root.after(5000, self.update_system_info)
        except Exception as e:
            logging.error(f"Error updating system info: {e}")

    def update_battery_status(self):
        if not self.running:
            return
        logging.debug("Updating battery status")
        try:
            if hasattr(psutil, 'sensors_battery'):
                battery = psutil.sensors_battery()
                if battery:
                    percent = battery.percent
                    secs_left = battery.secsleft if battery.secsleft != psutil.POWER_TIME_UNKNOWN else "Unknown"
                    time_left = f"{secs_left // 3600}h {secs_left % 3600 // 60}m" if secs_left != "Unknown" else "Unknown"
                    self.battery_label.config(text=self.get_text('battery_status', percent=percent, time=time_left))
                else:
                    self.battery_label.config(text=self.get_text('no_battery'))
            else:
                self.battery_label.config(text=self.get_text('no_battery'))
            if self.running:
                self.root.after(60000, self.update_battery_status)
        except Exception as e:
            logging.error(f"Error updating battery status: {e}")

    def set_keyboard_layout(self, layout):
        logging.debug(f"Setting keyboard layout to {layout}")
        try:
            subprocess.run(["swaymsg", f"input type:keyboard xkb_layout {layout}"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
        except Exception as e:
            logging.error(f"Error setting keyboard layout: {e}")

    def apply_keyboard_settings(self):
        logging.debug("Applying keyboard settings")
        try:
            rate = self.repeat_rate_var.get()
            delay = self.repeat_delay_var.get()
            if not (rate.isdigit() and delay.isdigit()) or int(rate) <= 0 or int(delay) <= 0:
                messagebox.showerror(self.get_text('title'), self.get_text('invalid_value'))
                return
            subprocess.run(["swaymsg", f"input type:keyboard xkb_repeat_rate {rate}"], check=False)
            subprocess.run(["swaymsg", f"input type:keyboard xkb_repeat_delay {delay}"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
            self.update_status("Keyboard settings applied")
        except Exception as e:
            logging.error(f"Error applying keyboard settings: {e}")

    def toggle_touchpad(self):
        logging.debug("Toggling touchpad")
        self.touchpad_enabled = not getattr(self, 'touchpad_enabled', True)
        state = "on" if self.touchpad_enabled else "off"
        try:
            subprocess.run(["swaymsg", f"input type:touchpad events {state}"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
        except Exception as e:
            logging.error(f"Error toggling touchpad: {e}")

    def apply_touchpad_sensitivity(self):
        logging.debug("Applying touchpad sensitivity")
        try:
            sensitivity = float(self.sensitivity_var.get())
            if sensitivity < 0 or sensitivity > 2:
                messagebox.showerror(self.get_text('title'), self.get_text('invalid_value'))
                return
            subprocess.run(["swaymsg", f"input type:touchpad accel_speed {sensitivity}"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
            self.update_status("Touchpad sensitivity applied")
        except Exception as e:
            logging.error(f"Error applying touchpad sensitivity: {e}")

    def get_wallpapers(self):
        logging.debug("Getting wallpapers")
        try:
            wallpaper_dir = "/usr/share/HackerOS/Wallpapers/"
            if not os.path.exists(wallpaper_dir):
                return ["Default"]
            return [f for f in os.listdir(wallpaper_dir) if f.endswith(('.png', '.jpg'))] or ["Default"]
        except Exception:
            return ["Default"]

    def set_wallpaper(self, wallpaper):
        logging.debug(f"Setting wallpaper to {wallpaper}")
        try:
            if wallpaper == "Default":
                subprocess.run(["swaymsg", "output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill"], check=False)
            else:
                wallpaper_path = f"/usr/share/HackerOS/Wallpapers/{wallpaper}"
                subprocess.run(["swaymsg", f"output * bg {wallpaper_path} fill"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
            self.update_status(f"Wallpaper set to {wallpaper}")
        except Exception as e:
            logging.error(f"Error setting wallpaper: {e}")

    def apply_ui_scaling(self):
        logging.debug("Applying UI scaling")
        try:
            scaling = float(self.scaling_var.get())
            if scaling < 0.5 or scaling > 3.0:
                messagebox.showerror(self.get_text('title'), self.get_text('invalid_value'))
                return
            subprocess.run(["swaymsg", f"output * scale {scaling}"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
            self.update_status("UI scaling applied")
        except Exception as e:
            logging.error(f"Error applying UI scaling: {e}")

    def apply_bar_transparency(self):
        logging.debug("Applying bar transparency")
        try:
            transparency = float(self.transparency_var.get())
            if not (0.0 <= transparency <= 1.0):
                messagebox.showerror(self.get_text('title'), self.get_text('invalid_value'))
                return
            config_path = f"/home/{getpass.getuser()}/.config/sway/config"
            if os.path.exists(config_path):
                with open(config_path, "r") as f:
                    config = f.read()
                new_config = re.sub(r"bar \{[^}]*opacity\s+[^}]*}", f"bar {{ opacity {transparency} }}", config, flags=re.DOTALL)
                with open(config_path, "w") as f:
                    f.write(new_config)
                subprocess.run(["swaymsg", "reload"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
            self.update_status("Bar transparency applied")
        except Exception as e:
            logging.error(f"Error applying bar transparency: {e}")

    def clear_logs(self):
        logging.debug("Clearing system logs")
        try:
            log_files = ["/tmp/hacker-mode.log", "/tmp/hacker-mode-settings.log"]
            for log_file in log_files:
                if os.path.exists(log_file):
                    with open(log_file, "w") as f:
                        f.write("")
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
        except Exception as e:
            logging.error(f"Error clearing logs: {e}")

    def restart_services(self):
        logging.debug("Restarting system services")
        try:
            subprocess.run(["systemctl", "restart", "NetworkManager"], check=False)
            subprocess.run(["systemctl", "restart", "bluetooth"], check=False)
            messagebox.showinfo(self.get_text('title'), self.get_text('success'))
        except Exception as e:
            logging.error(f"Error restarting services: {e}")

    def check_health(self):
        logging.debug("Checking system health")
        try:
            disk = psutil.disk_usage('/')
            memory = psutil.virtual_memory()
            disk_status = "OK" if disk.percent < 90 else "Critical"
            mem_status = "OK" if memory.percent < 90 else "Critical"
            messagebox.showinfo(self.get_text('title'), self.get_text('health_status', disk_status=disk_status, mem_status=mem_status))
            self.update_status("System health checked")
        except Exception as e:
            logging.error(f"Error checking health: {e}")

    def logout(self):
        logging.debug("Logging out")
        subprocess.run(["swaymsg", "exit"], check=False)

    def restart_sway(self):
        logging.debug("Restarting Sway")
        subprocess.run(["swaymsg", "reload"], check=False)

    def switch_to_plasma(self):
        logging.debug("Switching to Plasma")
        subprocess.run(["systemctl", "start", "plasma-kde"], check=False)

    def shutdown(self):
        logging.debug("Shutting down")
        subprocess.run(["systemctl", "poweroff"], check=False)

    def restart(self):
        logging.debug("Restarting")
        subprocess.run(["systemctl", "reboot"], check=False)

def main():
    logging.debug("Starting main function")
    os.environ["XDG_SESSION_TYPE"] = 'wayland'
    try:
        root = tk.Tk()
        app = HackerModeSettings(root)
        root.mainloop()
    except Exception as e:
        logging.error(f"Error in main loop: {e}")
        print(f"Error: {e}")
        raise

if __name__ == "__main__":
    main()
