#!/usr/bin/env python3

import tkinter as tk
from tkinter import font as tkfont, messagebox
from PIL import Image, ImageTk
import subprocess
import os
import getpass
import locale
import logging
from functools import partial
import asyncio
import threading
import time

# Ustawienie logowania dla debugowania
logging.basicConfig(level=logging.DEBUG, filename='/tmp/hacker-mode.log', filemode='a',
                    format='%(asctime)s - %(levelname)s - %(message)s')

class HackerMode:
    def __init__(self, root):
        logging.debug("Initializing HackerMode")
        self.root = root
        self.running_processes = []
        self.is_muted = False
        self.is_dark_mode = True
        self.config_frame = None
        self.wifi_action_lock = False
        self.last_launch_times = {}  # Dictionary to track last launch times
        self.setup_language()
        self.setup_colors()
        self.setup_window()
        self.setup_fonts()
        self.setup_ui()
        self.make_fullscreen()

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
                'title': "Hacker Mode",
                'settings': "Settings",
                'hacker_menu': "HACKER MENU",
                'steam': "Steam",
                'heroic': "Heroic",
                'lutris': "Lutris",
                'audio': "Audio",
                'increase_volume': "Increase Volume",
                'decrease_volume': "Decrease Volume",
                'toggle_mute': "Toggle Mute",
                'display': "Display",
                'increase_brightness': "Increase Brightness",
                'decrease_brightness': "Decrease Brightness",
                'toggle_theme': "Toggle Dark/Light Mode",
                'change_resolution': "Change Resolution",
                'network': "Network",
                'wifi_settings': "Wi-Fi Settings",
                'connect_wifi': "Connect to Wi-Fi",
                'toggle_wifi': "Toggle Wi-Fi",
                'bluetooth': "Bluetooth",
                'power': "Power",
                'power_saving': "Power Saving",
                'balanced': "Balanced",
                'performance': "Performance",
                'screen_timeout': "Screen Timeout (minutes)",
                'general': "General",
                'toggle_notifications': "Toggle Notifications",
                'change_language': "Change Language",
                'shortcut_info': "Close App Shortcut (Win + E)",
                'update_system': "Update System",
                'update_output': "Update completed successfully:\n{output}",
                'update_failed': "Update failed:\n{error}",
                'update_script_missing': "Update script not found.",
                'switch_plasma': "Switch to Plasma",
                'shutdown': "Shutdown",
                'restart': "Restart",
                'sleep': "Sleep",
                'restart_apps': "Restart Apps",
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
                'no_internet': "No internet connection. Please enable Wi-Fi.",
                'shortcut_note': "Configure Win + E in Sway to close Lutris or Steam and reopen Hacker Mode",
                'app_not_installed': "To install missing applications use the hacker-mode-install command on the terminal.",
                'launch_cooldown': "Please wait {seconds} seconds before launching {app} again."
            },
            'pl': {
                'title': "Tryb Hakera",
                'settings': "Ustawienia",
                'hacker_menu': "MENU HAKERA",
                'steam': "Steam",
                'heroic': "Heroic",
                'lutris': "Lutris",
                'audio': "Dźwięk",
                'increase_volume': "Zwiększ głośność",
                'decrease_volume': "Zmniejsz głośność",
                'toggle_mute': "Wycisz/Włącz dźwięk",
                'display': "Wyświetlacz",
                'increase_brightness': "Zwiększ jasność",
                'decrease_brightness': "Zmniejsz jasność",
                'toggle_theme': "Przełącz tryb ciemny/jasny",
                'change_resolution': "Zmień rozdzielczość",
                'network': "Sieć",
                'wifi_settings': "Ustawienia Wi-Fi",
                'connect_wifi': "Połącz z Wi-Fi",
                'toggle_wifi': "Włącz/Wyłącz Wi-Fi",
                'bluetooth': "Bluetooth",
                'power': "Zasilanie",
                'power_saving': "Oszczędzanie energii",
                'balanced': "Zrównoważony",
                'performance': "Wydajność",
                'screen_timeout': "Czas wygaszania ekranu (minuty)",
                'general': "Ogólne",
                'toggle_notifications': "Włącz/Wyłącz powiadomienia",
                'change_language': "Zmień język",
                'shortcut_info': "Skrót do zamykania aplikacji (Win + E)",
                'update_system': "Aktualizuj system",
                'update_output': "Aktualizacja zakończona pomyślnie:\n{output}",
                'update_failed': "Aktualizacja nieudana:\n{error}",
                'update_script_missing': "Skrypt aktualizacji nie znaleziony.",
                'switch_plasma': "Przełącz na Plasma",
                'shutdown': "Wyłącz",
                'restart': "Uruchom ponownie",
                'sleep': "Uśpij",
                'restart_apps': "Restartuj aplikacje",
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
                'no_internet': "Brak połączenia z internetem. Proszę włączyć Wi-Fi.",
                'shortcut_note': "Skonfiguruj Win + E w Sway, aby zamykać Lutris lub Steam i otwierać Tryb Hakera",
                'app_not_installed': "Aby zainstalować brakujące aplikacje, użyj polecenia hacker-mode-install w terminalu.",
                'launch_cooldown': "Proszę czekać {seconds} sekund przed ponownym uruchomieniem {app}."
            }
        }
        if self.lang not in self.translations:
            self.lang = 'en'
        self._cached_translations = self.translations[self.lang]

    def get_text(self, key, **kwargs):
        return self._cached_translations.get(key, key).format(**kwargs)

    def setup_colors(self):
        logging.debug("Setting up colors")
        self.bg_color = '#1A1A1A'
        self.menu_color = '#2D2D2D'
        self.accent_color = '#FFFFFF'
        self.text_color = '#E0E0E0'
        self.highlight_color = '#3D3D3D'

    def setup_window(self):
        logging.debug("Setting up window")
        try:
            self.root.title(self.get_text('title'))
            self.root.configure(bg=self.bg_color)
            self.root.bind('<Escape>', lambda e: self.on_closing())
            self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
            self.root.attributes('-topmost', False)
            self.root.wm_attributes('-type', 'normal')
        except Exception as e:
            logging.error(f"Error setting up window: {e}")

    def make_fullscreen(self):
        logging.debug("Making window fullscreen in Sway")
        try:
            subprocess.run(["swaymsg", "fullscreen enable"], check=False)
        except Exception as e:
            logging.error(f"Error setting fullscreen in Sway: {e}")

    def setup_fonts(self):
        logging.debug("Setting up fonts")
        try:
            self.title_font = tkfont.Font(family='Courier', size=14, weight='bold')
            self.button_font = tkfont.Font(family='Courier', size=11)
            self.menu_font = tkfont.Font(family='Courier', size=10)
        except Exception as e:
            logging.error(f"Error setting up fonts: {e}")

    def on_closing(self):
        logging.debug("Closing application")
        for _, process in self.running_processes:
            try:
                process.terminate()
                process.wait(timeout=2)
            except:
                process.kill()
        self.root.destroy()

    def setup_ui(self):
        logging.debug("Setting up UI")
        try:
            self.setup_header()
            self.setup_app_launchers()
            self.setup_footer()
        except Exception as e:
            logging.error(f"Error setting up UI: {e}")

    def setup_header(self):
        logging.debug("Setting up header")
        logo_path = "/usr/share/HackerOS/ICONS/Hacker-Mode.png"
        if os.path.exists(logo_path):
            try:
                logo_img = Image.open(logo_path).resize((80, 80), Image.LANCZOS)
                self.logo_photo = ImageTk.PhotoImage(logo_img)
                tk.Label(self.root, image=self.logo_photo, bg=self.bg_color, bd=0).place(relx=0.95, rely=0.05, anchor='ne')
            except Exception as e:
                logging.error(f"Error loading logo: {e}")
        else:
            logging.error(f"Logo file not found at {logo_path}")

    def setup_app_launchers(self):
        logging.debug("Setting up app launchers")
        apps = [
            ("steam.png", self.get_text('steam'), ["flatpak", "run", "com.valvesoftware.Steam", "-gamepadui"], False, True),
            ("heroic.png", self.get_text('heroic'), ["flatpak", "run", "com.heroicgameslauncher.hgl"], False, False),
            ("lutris.png", self.get_text('lutris'), ["lutris"], False, False),
        ]

        main_frame = tk.Frame(self.root, bg=self.bg_color)
        main_frame.place(relx=0.5, rely=0.5, anchor='center')

        for idx, (icon, name, cmd, use_root, requires_internet) in enumerate(apps):
            icon_path = f"/usr/share/HackerOS/ICONS/{icon}"
            btn = None
            if os.path.exists(icon_path):
                try:
                    img = Image.open(icon_path).resize((110, 110), Image.LANCZOS)
                    photo = ImageTk.PhotoImage(img)
                    btn = tk.Button(
                        main_frame, image=photo, text=name, compound='top',
                        command=partial(self.launch_app, cmd, use_root, name, requires_internet),
                        bg=self.bg_color, fg=self.accent_color, font=self.button_font,
                        activebackground=self.highlight_color, relief='flat', borderwidth=0,
                        padx=15, pady=10
                    )
                    btn.image = photo
                except Exception as e:
                    logging.error(f"Error loading icon {icon}: {e}")
            if btn is None:
                btn = tk.Button(
                    main_frame, text=name, command=partial(self.launch_app, cmd, use_root, name, requires_internet),
                    bg=self.bg_color, fg=self.accent_color, font=self.button_font,
                    padx=20, pady=15
                )
            btn.grid(row=0, column=idx, padx=20)
            btn.bind("<Enter>", lambda e, b=btn: b.config(bg=self.highlight_color))
            btn.bind("<Leave>", lambda e, b=btn: b.config(bg=self.bg_color))

    def setup_footer(self):
        logging.debug("Setting up footer")
        menu_frame = tk.Frame(self.root, bg=self.menu_color)
        menu_frame.place(relx=0.0, rely=1.0, anchor='sw')

        settings_path = "/usr/share/HackerOS/ICONS/settings.png"
        if os.path.exists(settings_path):
            try:
                settings_img = Image.open(settings_path).resize((24, 24), Image.LANCZOS)
                self.settings_photo = ImageTk.PhotoImage(settings_img)
                settings_button = tk.Button(
                    menu_frame, image=self.settings_photo, command=self.launch_settings_gui,
                    bg='#000000', activebackground='#3D3D3D', relief='flat', borderwidth=0,
                    padx=10, pady=5
                )
            except Exception as e:
                logging.error(f"Error loading settings icon: {e}")
                settings_button = tk.Button(
                    menu_frame, text=self.get_text('settings'), command=self.launch_settings_gui,
                    bg='#000000', fg='#FFFFFF', font=self.button_font,
                    activebackground='#3D3D3D', activeforeground='#FFFFFF',
                    relief='flat', padx=10, pady=5, borderwidth=0
                )
        else:
            settings_button = tk.Button(
                menu_frame, text=self.get_text('settings'), command=self.launch_settings_gui,
                bg='#000000', fg='#FFFFFF', font=self.button_font,
                activebackground='#3D3D3D', activeforeground='#FFFFFF',
                relief='flat', padx=10, pady=5, borderwidth=0
            )
        settings_button.pack(side='left', padx=5)
        settings_button.bind("<Enter>", lambda e: settings_button.config(bg=self.highlight_color))
        settings_button.bind("<Leave>", lambda e: settings_button.config(bg='#000000'))
        self.settings_button = settings_button

        self.hacker_button = tk.Button(
            menu_frame, text=self.get_text('hacker_menu'), command=self.show_hacker_menu,
            bg='#000000', fg='#FFFFFF', font=self.button_font,
            activebackground='#3D3D3D', activeforeground='#FFFFFF',
            relief='flat', padx=15, pady=5, borderwidth=0
        )
        self.hacker_button.pack(side='left', padx=5)

        self.hacker_menu = tk.Menu(
            self.root, tearoff=0, bg='#000000', fg='#FFFFFF', font=self.menu_font,
            activebackground='#3D3D3D', activeforeground='#FFFFFF', bd=0
        )
        self.hacker_menu.add_command(label=self.get_text('switch_plasma'), command=self.switch_to_plasma)
        self.hacker_menu.add_separator()
        self.hacker_menu.add_command(label=self.get_text('shutdown'), command=self.shutdown)
        self.hacker_menu.add_command(label=self.get_text('restart'), command=self.restart)
        self.hacker_menu.add_command(label=self.get_text('sleep'), command=self.sleep)
        self.hacker_menu.add_command(label=self.get_text('restart_apps'), command=self.restart_apps)
        self.hacker_menu.add_command(label=self.get_text('log_out'), command=self.logout)
        self.hacker_menu.add_command(label=self.get_text('restart_sway'), command=self.restart_sway)

    def launch_settings_gui(self):
        logging.debug("Launching external settings GUI")
        try:
            settings_script = "/usr/share/HackerOS/Scripts/HackerOS-Apps/Hacker-Mode/Hacker-Mode-Settings.py"
            if not os.path.exists(settings_script):
                logging.error(f"Settings script not found at {settings_script}")
                messagebox.showerror(self.get_text('title'), f"Settings script not found at {settings_script}")
                return

            # Close current application
            self.on_closing()

            # Launch the external settings script
            env = os.environ.copy()
            env['XDG_SESSION_TYPE'] = 'wayland'
            subprocess.Popen(["python3", settings_script], env=env, start_new_session=True)
            logging.debug("External settings GUI launched")
        except Exception as e:
            logging.error(f"Error launching settings GUI: {e}")
            messagebox.showerror(self.get_text('title'), f"Error launching settings: {e}")

    def show_hacker_menu(self):
        logging.debug("Showing hacker menu")
        try:
            self.hacker_menu.tk_popup(
                self.hacker_button.winfo_rootx(),
                self.hacker_button.winfo_rooty() - 150
            )
        except Exception as e:
            logging.error(f"Error showing hacker menu: {e}")

    def clear_config_frame(self):
        if self.config_frame is not None:
            self.config_frame.destroy()
        self.config_frame = tk.Frame(self.root, bg=self.menu_color, bd=2, relief='raised')
        self.config_frame.place(relx=0.75, rely=0.5, anchor='center', width=400, height=400)

    def show_wifi_settings(self):
        logging.debug("Showing Wi-Fi settings")
        self.clear_config_frame()
        tk.Label(self.config_frame, text=self.get_text('wifi_list'), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
        try:
            result = subprocess.run(["nmcli", "-t", "-f", "SSID,SIGNAL", "dev", "wifi"], capture_output=True, text=True, check=False)
            networks = [line.split(":") for line in result.stdout.strip().split("\n") if line]
            if not networks:
                tk.Label(self.config_frame, text=self.get_text('no_networks'), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
                return

            wifi_listbox = tk.Listbox(self.config_frame, bg=self.menu_color, fg=self.text_color, font=self.button_font, height=10)
            wifi_listbox.pack(pady=5, padx=5, fill='both', expand=True)
            for ssid, signal in networks:
                wifi_listbox.insert(tk.END, f"{ssid} ({signal}%)")

            tk.Label(self.config_frame, text="Password (if required):", bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
            password_entry = tk.Entry(self.config_frame, bg=self.menu_color, fg=self.text_color, show="*")
            password_entry.pack(pady=5)
            tk.Button(self.config_frame, text=self.get_text('connect'), command=lambda: self.connect_wifi_from_list(wifi_listbox, password_entry.get()), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
        except Exception as e:
            logging.error(f"Error showing Wi-Fi settings: {e}")

    def connect_wifi_from_list(self, listbox, password):
        logging.debug("Connecting to selected Wi-Fi")
        try:
            selection = listbox.curselection()
            if not selection:
                tk.Label(self.config_frame, text=self.get_text('no_selection'), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
                return
            selected = listbox.get(selection)
            ssid = selected.split(" (")[0]
            cmd = ["nmcli", "dev", "wifi", "connect", ssid]
            if password:
                cmd.extend(["password", password])
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            tk.Label(self.config_frame, text=self.get_text('connecting' if result.returncode == 0 else 'connection_failed', ssid=ssid, error=result.stderr), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
        except Exception as e:
            logging.error(f"Error connecting to Wi-Fi: {e}")
            tk.Label(self.config_frame, text=self.get_text('connection_failed', error=str(e)), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)

    def show_wifi_networks(self):
        logging.debug("Showing Wi-Fi networks")
        self.clear_config_frame()
        tk.Label(self.config_frame, text=self.get_text('wifi_list'), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
        try:
            result = subprocess.run(["nmcli", "-t", "-f", "SSID,SIGNAL", "dev", "wifi"], capture_output=True, text=True, check=False)
            networks = [line.split(":") for line in result.stdout.strip().split("\n") if line]
            if not networks:
                tk.Label(self.config_frame, text=self.get_text('no_networks'), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
                return
            for ssid, signal in networks:
                tk.Button(self.config_frame, text=f"{ssid} ({signal}%)", command=lambda s=ssid: self.connect_wifi(s), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=2)
        except Exception as e:
            logging.error(f"Error showing Wi-Fi networks: {e}")

    def connect_wifi(self, ssid):
        logging.debug(f"Connecting to Wi-Fi {ssid}")
        try:
            result = subprocess.run(["nmcli", "dev", "wifi", "connect", ssid], capture_output=True, text=True, check=False)
            tk.Label(self.config_frame, text=self.get_text('connecting' if result.returncode == 0 else 'connection_failed', ssid=ssid, error=result.stderr), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
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
            tk.Label(self.config_frame, text=self.get_text('wifi_toggle_success' if result.returncode == 0 else 'wifi_toggle_failed', state=action, error=result.stderr), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
        except Exception as e:
            logging.error(f"Error toggling Wi-Fi: {e}")
        finally:
            self.wifi_action_lock = False

    def check_internet(self):
        logging.debug("Checking internet connection")
        try:
            # First check nmcli connectivity
            result = subprocess.run(["nmcli", "networking", "connectivity"], capture_output=True, text=True, check=False)
            status = result.stdout.strip()
            logging.debug(f"nmcli connectivity status: {status}")
            if status == "full":
                return True
            
            # Additional check with ping
            ping_result = subprocess.run(["ping", "-c", "1", "8.8.8.8"], capture_output=True, text=True, check=False)
            if ping_result.returncode == 0:
                return True
            
            # Fallback with curl
            curl_result = subprocess.run(["curl", "-s", "--max-time", "5", "http://www.google.com"], capture_output=True, text=True, check=False)
            logging.debug(f"Curl result: {curl_result.returncode}, output: {curl_result.stdout}")
            return curl_result.returncode == 0
        except Exception as e:
            logging.error(f"Error checking internet: {e}")
            return False

    def ensure_internet(self):
        logging.debug("Ensuring internet connection")
        if self.check_internet():
            logging.debug("Internet connection confirmed")
            return True
        logging.error("No internet connection detected")
        return False

    def show_bluetooth(self):
        logging.debug("Showing Bluetooth")
        self.clear_config_frame()
        tk.Label(self.config_frame, text=self.get_text('bluetooth_devices'), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
        tk.Button(self.config_frame, text=self.get_text('scan'), command=self.scan_bluetooth, bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
        self.bluetooth_listbox = tk.Listbox(self.config_frame, bg=self.menu_color, fg=self.text_color, font=self.button_font, height=8)
        self.bluetooth_listbox.pack(pady=5, padx=5, fill='both', expand=True)
        tk.Button(self.config_frame, text=self.get_text('pair'), command=self.pair_bluetooth, bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)

    def scan_bluetooth(self):
        logging.debug("Scanning Bluetooth devices")
        try:
            subprocess.run(["bluetoothctl", "power", "on"], check=False)
            subprocess.run(["bluetoothctl", "scan", "on"], check=False)
            result = subprocess.run(["bluetoothctl", "devices"], capture_output=True, text=True, check=False)
            subprocess.run(["bluetoothctl", "scan", "off"], check=False)
            devices = [line for line in result.stdout.strip().split("\n") if line.startswith("Device")]
            self.bluetooth_listbox.delete(0, tk.END)
            if not devices:
                tk.Label(self.config_frame, text="No devices found", bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
            for device in devices:
                self.bluetooth_listbox.insert(tk.END, device)
        except Exception as e:
            logging.error(f"Error scanning Bluetooth: {e}")

    def pair_bluetooth(self):
        logging.debug("Pairing Bluetooth device")
        try:
            selection = self.bluetooth_listbox.curselection()
            if not selection:
                tk.Label(self.config_frame, text=self.get_text('no_selection'), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
                return
            selected = self.bluetooth_listbox.get(selection)
            device_id = selected.split()[1]
            tk.Label(self.config_frame, text=self.get_text('pairing', device=device_id), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
            pair_result = subprocess.run(["bluetoothctl", "pair", device_id], capture_output=True, text=True, check=False)
            if pair_result.returncode != 0:
                tk.Label(self.config_frame, text=self.get_text('pairing_failed', error=pair_result.stderr), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
                return
            connect_result = subprocess.run(["bluetoothctl", "connect", device_id], capture_output=True, text=True, check=False)
            if connect_result.returncode != 0:
                tk.Label(self.config_frame, text=self.get_text('pairing_failed', error=connect_result.stderr), bg=self.menu_color, fg=self.text_color, font=self.button_font).pack(pady=5)
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
                with open(config_path, "r") as f:
                    config = f.read()
                new_config = config.replace(
                    f"set $theme {'light' if self.is_dark_mode else 'dark'}",
                    f"set $theme {theme}"
                )
                with open(config_path, "w") as f:
                    f.write(new_config)
                subprocess.run(["swaymsg", "reload"], check=False)
        except Exception as e:
            logging.error(f"Error toggling theme: {e}")

    def toggle_notifications(self):
        logging.debug("Toggling notifications")
        self.notifications_enabled = not getattr(self, 'notifications_enabled', True)
        if subprocess.run(["which", "makoctl"], capture_output=True).returncode == 0:
            subprocess.run(["makoctl", "set-mode", "do-not-disturb" if not self.notifications_enabled else "default"], check=False)

    def set_power_profile(self, profile):
        logging.debug(f"Setting power profile to {profile}")
        subprocess.run(["powerprofilesctl", "set", profile], check=False)

    def monitor_process(self, process, app_name):
        logging.debug(f"Monitoring process for {app_name}")
        try:
            process.wait()
            logging.debug(f"Process {app_name} terminated")
            self.running_processes = [(cmd, proc) for cmd, proc in self.running_processes if proc.pid != process.pid]
            self.root.deiconify()
            self.make_fullscreen()  # Restore fullscreen after app closes
            logging.debug(f"Hacker Mode reopened after {app_name} closed")
        except Exception as e:
            logging.error(f"Error monitoring process {app_name}: {e}")

    async def focus_app(self, app_id):
        logging.debug(f"Focusing and setting fullscreen for app_id: {app_id}")
        try:
            await asyncio.sleep(2)  # Increased delay to ensure app is ready
            subprocess.run(["swaymsg", f'[app_id="{app_id}"] focus'], check=False)
            subprocess.run(["swaymsg", f'[app_id="{app_id}"] fullscreen enable'], check=False)
        except Exception as e:
            logging.error(f"Error focusing or setting fullscreen for {app_id}: {e}")

    def check_app_installed(self, command, app_name):
        logging.debug(f"Checking if {app_name} is installed with command: {command}")
        try:
            if "flatpak" in command:
                flatpak_id = command[2]  # Flatpak ID is now at index 2
                result = subprocess.run(["flatpak", "list", "--app", "--columns=application"], capture_output=True, text=True, check=False)
                installed_apps = [app.strip() for app in result.stdout.strip().split("\n") if app.strip()]
                logging.debug(f"Flatpak installed apps: {installed_apps}")
                logging.debug(f"Checking for Flatpak ID: {flatpak_id}")
                if flatpak_id not in installed_apps:
                    messagebox.showerror(self.get_text('title'), self.get_text('app_not_installed'))
                    return False
                return True
            else:
                result = subprocess.run(["which", command[0]], capture_output=True, text=True, check=False)
                logging.debug(f"Which output for {command[0]}: {result.stdout}")
                if result.returncode != 0:
                    messagebox.showerror(self.get_text('title'), self.get_text('app_not_installed'))
                    return False
                return True
        except Exception as e:
            logging.error(f"Error checking if {app_name} is installed: {e}")
            messagebox.showerror(self.get_text('title'), self.get_text('app_not_installed'))
            return False

    def launch_app(self, command, use_root=False, app_name="App", requires_internet=False):
        logging.debug(f"Launching app {command} (app_name: {app_name}, use_root: {use_root}, requires_internet: {requires_internet})")
        try:
            # Check launch cooldown
            current_time = time.time()
            last_launch = self.last_launch_times.get(app_name, 0)
            cooldown_seconds = 60
            if current_time - last_launch < cooldown_seconds:
                remaining = int(cooldown_seconds - (current_time - last_launch))
                messagebox.showerror(self.get_text('title'), self.get_text('launch_cooldown', app=app_name, seconds=remaining))
                logging.debug(f"Launch blocked for {app_name} due to cooldown. Remaining: {remaining}s")
                return

            # Check if app is installed
            if not self.check_app_installed(command, app_name):
                logging.error(f"{app_name} not detected as installed")
                return

            # Check internet connection if required
            if requires_internet and not self.ensure_internet():
                logging.error("No internet connection for app requiring internet")
                messagebox.showerror(self.get_text('title'), self.get_text('no_internet'))
                return

            # Hide Hacker Mode
            self.root.withdraw()
            logging.debug("Hacker Mode window withdrawn")

            # Set up language and environment
            lang_map = {
                'en': 'en_US.UTF-8',
                'pl': 'pl_PL.UTF-8'
            }
            app_lang = lang_map.get(self.lang, 'en_US.UTF-8')

            final_cmd = ["pkexec"] + command if use_root else command
            app_id = command[2] if "flatpak" in command else command[0].split("/")[-1]

            env = os.environ.copy()
            env['LANG'] = app_lang
            env['XDG_SESSION_TYPE'] = 'wayland'

            # Launch the application
            logging.debug(f"Executing command: {final_cmd}")
            process = subprocess.Popen(final_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, start_new_session=True, text=True)
            self.running_processes.append((command[0], process))

            # Update last launch time
            self.last_launch_times[app_name] = current_time
            logging.debug(f"Updated last launch time for {app_name}")

            # Start monitoring the process
            threading.Thread(target=self.monitor_process, args=(process, app_id), daemon=True).start()
            threading.Thread(target=lambda: asyncio.run(self.focus_app(app_id)), daemon=True).start()

        except Exception as e:
            logging.error(f"Error launching app {command}: {e}")
            messagebox.showerror(self.get_text('title'), f"Error launching {app_name}: {e}")
            self.root.deiconify()
            self.make_fullscreen()

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

    def sleep(self):
        logging.debug("Suspending")
        subprocess.run(["systemctl", "suspend"], check=False)

    def restart_apps(self):
        logging.debug("Restarting apps")
        for app in ["steam", "heroic", "lutris"]:
            subprocess.run(["pkill", "-f", app], stderr=subprocess.DEVNULL, check=False)
        self.running_processes.clear()
        self.root.deiconify()
        self.make_fullscreen()

def main():
    logging.debug("Starting main function")
    os.environ["XDG_SESSION_TYPE"] = "wayland"
    try:
        root = tk.Tk()
        app = HackerMode(root)
        root.mainloop()
    except Exception as e:
        logging.error(f"Error in main loop: {e}")
        print(f"Error: {e}")
        raise

if __name__ == "__main__":
    main()
