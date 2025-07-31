import sys
import os
import subprocess
import logging
import base64
import json
import shutil
import yaml
from datetime import datetime
from typing import List, Dict
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QPushButton, QVBoxLayout, QWidget, QLabel,
    QTextEdit, QMessageBox, QHBoxLayout, QTabWidget, QLineEdit, QScrollArea,
    QMenu, QAction, QGridLayout, QToolBar, QComboBox, QProgressBar,
    QDialog, QInputDialog, QCheckBox, QStatusBar, QSizePolicy,
    QTableWidget, QTableWidgetItem, QHeaderView, QFileDialog, QSpinBox,
    QGroupBox, QFormLayout, QSplitter, QTreeWidget, QTreeWidgetItem, QDockWidget,
    QToolButton, QProgressDialog, QDateEdit, QGraphicsView, QGraphicsScene
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QTimer, QPoint, QSize, QSettings, QThreadPool, QDate, QPropertyAnimation, QRectF
from PyQt5.QtGui import QFont, QIcon, QPixmap, QCursor, QColor, QBrush, QPainter, QPen, QLinearGradient
import requests
from urllib.parse import urlparse
from pathlib import Path
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler("hackeros.log"), logging.StreamHandler()]
)

# Encryption key generation
def generate_key(password: str = "default_password") -> bytes:
    salt = b'hackeros_salt_2025'
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    return base64.urlsafe_b64encode(kdf.derive(password.encode()))

# Load optional YAML config
CONFIG_PATH = "/etc/xdg/Penetration-Mode/config.yaml"
def load_yaml_config() -> Dict:
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                return yaml.safe_load(f) or {}
        except (yaml.YAMLError, IOError) as e:
            logging.error(f"Failed to load config from {CONFIG_PATH}: {str(e)}")
    return {}

# Funkcja do uruchamiania komend z uprawnieniami roota
def run_with_privileges(command: List[str], timeout: int = None) -> subprocess.CompletedProcess:
    try:
        result = subprocess.run(['pkexec'] + command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
        if result.returncode == 126 or result.returncode == 127:
            raise subprocess.CalledProcessError(result.returncode, command, output="Authentication canceled by user")
        return result
    except subprocess.TimeoutExpired:
        raise
    except subprocess.CalledProcessError as e:
        raise subprocess.CalledProcessError(e.returncode, command, output=e.output, stderr=e.stderr)

class ProcessWorker(QThread):
    output_signal = pyqtSignal(str)
    error_signal = pyqtSignal(str)
    finished_signal = pyqtSignal()
    progress_signal = pyqtSignal(int)

    def __init__(self, command: List[str], timeout: int = 60):
        super().__init__()
        self.command = command
        self.timeout = timeout

    def run(self):
        try:
            result = run_with_privileges(self.command, timeout=self.timeout)
            self.progress_signal.emit(100)
            if result.stdout:
                self.output_signal.emit(result.stdout)
            if result.stderr:
                self.error_signal.emit(result.stderr)
            self.finished_signal.emit()
        except subprocess.TimeoutExpired:
            self.error_signal.emit(f"Timeout ({self.timeout}s) for command: {' '.join(self.command)}")
        except subprocess.CalledProcessError as e:
            self.error_signal.emit(f"Execution error: {e.stderr or str(e)}")
        except Exception as e:
            self.error_signal.emit(f"Unexpected error: {str(e)}")

class NetworkDialog(QDialog):
    def __init__(self, parent, network_type: str = "Wi-Fi"):
        super().__init__(parent)
        self.network_type = network_type
        self.setWindowTitle(f"Manage {network_type}")
        self.setModal(True)
        self.setFixedSize(500, 400)
        layout = QVBoxLayout(self)

        self.network_tree = QTreeWidget()
        self.network_tree.setHeaderLabels(["Name", "Status", "Signal"])
        self.network_tree.setColumnWidth(0, 200)
        layout.addWidget(self.network_tree)

        button_layout = QHBoxLayout()
        self.refresh_button = QPushButton("Refresh")
        self.refresh_button.clicked.connect(self.refresh_networks)
        button_layout.addWidget(self.refresh_button)

        self.connect_button = QPushButton("Connect")
        self.connect_button.clicked.connect(self.connect_to_network)
        button_layout.addWidget(self.connect_button)

        self.disconnect_button = QPushButton("Disconnect")
        self.disconnect_button.clicked.connect(self.disconnect_from_network)
        button_layout.addWidget(self.disconnect_button)
        layout.addLayout(button_layout)

        if network_type == "Bluetooth":
            self.multi_connect = QCheckBox("Multiple Devices")
            layout.addWidget(self.multi_connect)

        self.refresh_networks()

    def refresh_networks(self):
        self.network_tree.clear()
        try:
            if self.network_type == "Wi-Fi":
                result = run_with_privileges(["nmcli", "-t", "-f", "SSID,ACTIVE,SIGNAL", "dev", "wifi"])
                for line in result.stdout.splitlines():
                    ssid, active, signal = line.split(":")
                    item = QTreeWidgetItem([ssid, "Active" if active == "yes" else "Inactive", signal])
                    self.network_tree.addTopLevelItem(item)
            elif self.network_type == "Bluetooth":
                result = run_with_privileges(["bluetoothctl", "devices"])
                for line in result.stdout.splitlines():
                    if line.startswith("Device"):
                        parts = line.split()
                        name = " ".join(parts[2:])
                        item = QTreeWidgetItem([name, "Unknown", "N/A"])
                        self.network_tree.addTopLevelItem(item)
        except subprocess.CalledProcessError as e:
            self.parent().log_error(f"Error refreshing {self.network_type}: {str(e)}")
        except Exception as e:
            self.parent().log_error(f"Unexpected error refreshing {self.network_type}: {str(e)}")

    def connect_to_network(self):
        selected = self.network_tree.currentItem()
        if not selected:
            QMessageBox.warning(self, "Error", "Select a network or device!")
            return
        target = selected.text(0)
        progress = QProgressDialog(f"Connecting to {target}...", "Cancel", 0, 0, self)
        progress.setWindowModality(Qt.WindowModal)
        progress.show()
        try:
            if self.network_type == "Wi-Fi":
                password, ok = QInputDialog.getText(self, "Password", f"Enter password for {target}:", echo=QLineEdit.Password)
                if ok and password:
                    cmd = ["nmcli", "dev", "wifi", "connect", target, "password", password]
                    run_with_privileges(cmd, timeout=30)
                    self.parent().output.append(f"Connected to {target}.")
            elif self.network_type == "Bluetooth":
                cmd = ["bluetoothctl", "connect", target]
                run_with_privileges(cmd, timeout=30)
                self.parent().output.append(f"Connected to {target}")
                if self.multi_connect.isChecked():
                    self.network_tree.setSelectionMode(QTreeWidget.MultiSelection)
            progress.close()
        except subprocess.TimeoutExpired:
            self.parent().log_error(f"Connection timeout for {target}")
            progress.close()
        except subprocess.CalledProcessError as e:
            self.parent().log_error(f"Connection error for {target}: {str(e)}")
            progress.close()

    def disconnect_from_network(self):
        selected = self.network_tree.currentItem()
        if not selected:
            QMessageBox.warning(self, "Error", "Select a network or device!")
            return
        target = selected.text(0)
        try:
            if self.network_type == "Wi-Fi":
                run_with_privileges(["nmcli", "con", "down", target], timeout=30)
                self.parent().output.append(f"Disconnected from {target}")
            elif self.network_type == "Bluetooth":
                run_with_privileges(["bluetoothctl", "disconnect", target], timeout=30)
                self.parent().output.append(f"Disconnected from {target}")
        except subprocess.TimeoutExpired:
            self.parent().log_error(f"Disconnection timeout for {target}")
        except subprocess.CalledProcessError as e:
            self.parent().log_error(f"Disconnection error for {target}: {str(e)}")

class SettingsDialog(QDialog):
    def __init__(self, parent):
        super().__init__(parent)
        self.setWindowTitle("Settings")
        self.setModal(True)
        self.setFixedSize(600, 700)
        layout = QVBoxLayout(self)

        yaml_config = load_yaml_config()
        settings = self.parent().settings

        network_group = QGroupBox("Network Settings")
        network_layout = QFormLayout()
        self.interface_input = QLineEdit(yaml_config.get("interface", settings.value("interface", "wlan0")))
        network_layout.addRow("Default Interface:", self.interface_input)
        self.vpn_path_input = QLineEdit(yaml_config.get("vpn_path", settings.value("vpn_path", "/etc/openvpn/client.conf")))
        self.vpn_path_button = QPushButton("Browse")
        self.vpn_path_button.clicked.connect(self.select_vpn_path)
        vpn_layout = QHBoxLayout()
        vpn_layout.addWidget(self.vpn_path_input)
        vpn_layout.addWidget(self.vpn_path_button)
        network_layout.addRow("VPN Config Path:", vpn_layout)
        self.proxy_input = QLineEdit(yaml_config.get("proxy", settings.value("proxy", "http://localhost:8080")))
        network_layout.addRow("Proxy Server:", self.proxy_input)
        self.dns_input = QLineEdit(yaml_config.get("dns_servers", settings.value("dns_servers", "8.8.8.8,8.8.4.4")))
        network_layout.addRow("DNS Servers (comma-separated):", self.dns_input)
        network_group.setLayout(network_layout)
        layout.addWidget(network_group)

        app_group = QGroupBox("Application Settings")
        app_layout = QFormLayout()
        self.timeout_input = QSpinBox()
        self.timeout_input.setRange(1, 300)
        self.timeout_input.setValue(int(yaml_config.get("timeout", settings.value("timeout", 60))))
        app_layout.addRow("Command Timeout (seconds):", self.timeout_input)
        self.log_level_combo = QComboBox()
        self.log_level_combo.addItems(["INFO", "DEBUG", "WARNING", "ERROR"])
        self.log_level_combo.setCurrentText(yaml_config.get("log_level", settings.value("log_level", "INFO")))
        app_layout.addRow("Log Level:", self.log_level_combo)
        self.max_threads_input = QSpinBox()
        self.max_threads_input.setRange(1, 16)
        self.max_threads_input.setValue(int(yaml_config.get("max_threads", settings.value("max_threads", 4))))
        app_layout.addRow("Max Threads:", self.max_threads_input)
        self.encryption_key_input = QLineEdit(yaml_config.get("encryption_key", settings.value("encryption_key", "default_password")))
        app_layout.addRow("Encryption Key:", self.encryption_key_input)
        self.auto_update_check = QCheckBox("Enable Auto Updates")
        self.auto_update_check.setChecked(yaml_config.get("auto_update", settings.value("auto_update", True, type=bool)))
        app_layout.addRow(self.auto_update_check)
        app_group.setLayout(app_layout)
        layout.addWidget(app_group)

        profile_group = QGroupBox("User Profile")
        profile_layout = QFormLayout()
        self.profile_name_input = QLineEdit(yaml_config.get("profile_name", settings.value("profile_name", "default_user")))
        profile_layout.addRow("Profile Name:", self.profile_name_input)
        self.history_size_input = QSpinBox()
        self.history_size_input.setRange(10, 1000)
        self.history_size_input.setValue(int(yaml_config.get("history_size", settings.value("history_size", 100))))
        profile_layout.addRow("Max History Size:", self.history_size_input)
        profile_group.setLayout(profile_layout)
        layout.addWidget(profile_group)

        save_button = QPushButton("Save")
        save_button.clicked.connect(self.save_settings)
        layout.addWidget(save_button)

    def select_vpn_path(self):
        path, _ = QFileDialog.getOpenFileName(self, "Select VPN Config", "/etc/openvpn", "Config Files (*.conf *.ovpn)")
        if path:
            self.vpn_path_input.setText(path)

    def save_settings(self):
        try:
            settings_dict = {
                "interface": self.interface_input.text(),
                "vpn_path": self.vpn_path_input.text(),
                "proxy": self.proxy_input.text(),
                "dns_servers": self.dns_input.text(),
                "timeout": self.timeout_input.value(),
                "log_level": self.log_level_combo.currentText(),
                "max_threads": self.max_threads_input.value(),
                "encryption_key": self.encryption_key_input.text(),
                "auto_update": self.auto_update_check.isChecked(),
                "profile_name": self.profile_name_input.text(),
                "history_size": self.history_size_input.value()
            }
            for key, value in settings_dict.items():
                self.parent().settings.setValue(key, value)
            self.parent().threadpool.setMaxThreadCount(self.max_threads_input.value())
            self.parent().update_logging_level()
            self.parent().update_encryption_key(self.encryption_key_input.text())
            if QMessageBox.question(self, "Save to YAML", "Save settings to /etc/xdg/Penetration-Mode/config.yaml?",
                                   QMessageBox.Yes | QMessageBox.No) == QMessageBox.Yes:
                try:
                    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
                    with open(CONFIG_PATH, "w") as f:
                        yaml.safe_dump(settings_dict, f)
                    self.parent().output.append(f"Settings saved to {CONFIG_PATH}")
                except IOError as e:
                    self.parent().log_error(f"Failed to save YAML config: {str(e)}")
            self.accept()
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save settings: {str(e)}")

class PenetrationModeWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Penetration Mode - HackerOS")
        self.setWindowFlags(Qt.Window | Qt.WindowStaysOnTopHint)
        self.resize(1280, 720)

        # Sprawdzenie środowiska graficznego
        if not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY"):
            QMessageBox.critical(None, "Error", "No graphical environment detected. Please run in X11 or Wayland.")
            sys.exit(1)

        self.settings = QSettings("HackerOS", "PenetrationMode")
        self.yaml_config = load_yaml_config()
        self.threadpool = QThreadPool()
        self.threadpool.setMaxThreadCount(int(self.yaml_config.get("max_threads", self.settings.value("max_threads", 4))))
        self.encryption_key = self.yaml_config.get("encryption_key", self.settings.value("encryption_key", "default_password"))
        self.cipher_suite = Fernet(generate_key(self.encryption_key))
        self.user_profile = self.load_user_profile()

        self.cursor_pixmap = QPixmap(32, 32)
        self.cursor_pixmap.fill(Qt.transparent)
        painter = QPainter(self.cursor_pixmap)
        gradient = QLinearGradient(0, 0, 32, 32)
        gradient.setColorAt(0, QColor("#00FFFF"))
        gradient.setColorAt(1, QColor("#FF00FF"))
        painter.setBrush(QBrush(gradient))
        painter.setPen(QPen(QColor("#FFFFFF"), 2))
        painter.drawEllipse(2, 2, 28, 28)
        painter.end()
        self.setCursor(QCursor(self.cursor_pixmap))

        self.theme = self.yaml_config.get("theme", self.settings.value("theme", "Dark"))
        self.apply_theme()

        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.main_layout = QVBoxLayout(self.central_widget)
        self.main_layout.setContentsMargins(20, 20, 20, 20)
        self.main_layout.setSpacing(15)

        self.toolbar = QToolBar("System Tools")
        self.toolbar.setIconSize(QSize(48, 48))
        self.addToolBar(Qt.TopToolBarArea, self.toolbar)
        self.toolbar.setMovable(False)
        self.add_toolbar_button("bluetooth", self.manage_bluetooth, "Manage Bluetooth")
        self.add_toolbar_button("network-wireless", self.manage_wifi, "Manage Wi-Fi")
        self.add_toolbar_button("network-vpn", self.toggle_vpn, "Toggle VPN")
        self.add_toolbar_button("network-tor", self.toggle_tor, "Toggle Tor")
        self.add_toolbar_button("security-high", self.toggle_full_anonymity, "Full Anonymity")
        self.add_toolbar_button("preferences-system", self.open_settings, "Settings")
        self.add_toolbar_button("system-help", self.show_help, "Help")
        self.add_toolbar_button("view-refresh", self.check_anonymity, "Test Anonymity")
        self.add_toolbar_button("security-high", self.run_security_scan, "Security Scan")
        self.add_toolbar_button("system-software-update", self.check_updates, "Check Updates")
        self.add_toolbar_button("application-exit", self.close_app, "Close")

        self.header_layout = QHBoxLayout()
        self.header = QLabel("Penetration Mode - HackerOS")
        self.header.setAlignment(Qt.AlignCenter)
        self.header.setFont(QFont("Ubuntu Mono", 36, QFont.Bold))
        self.header_layout.addWidget(self.header)

        self.theme_combo = QComboBox()
        self.theme_combo.addItems(["Dark", "Light", "Hacker Green"])
        self.theme_combo.setCurrentText(self.theme)
        self.theme_combo.setFixedWidth(150)
        self.theme_combo.currentTextChanged.connect(self.change_theme)
        self.header_layout.addWidget(self.theme_combo)

        self.main_layout.addLayout(self.header_layout)

        self.tabs = QTabWidget()
        self.tabs.setTabPosition(QTabWidget.West)
        self.main_layout.addWidget(self.tabs, stretch=4)

        self.tool_categories = {
            "Scanning": [
                ("Nmap", "Network scanning", self.run_nmap, "nmap -sP 192.168.1.0/24", "nmap"),
                ("Masscan", "Fast port scanning", self.run_masscan, "masscan -p80 192.168.1.0/24", "masscan"),
                ("OpenVAS", "Vulnerability scanning", self.run_openvas, "openvas-start", "openvas"),
            ],
            "Exploits": [
                ("Metasploit", "Exploit testing", self.run_metasploit, "msfconsole", "metasploit-framework"),
                ("Sqlmap", "SQL Injection", self.run_sqlmap, "sqlmap -u http://example.com", "sqlmap"),
            ],
            "Wireless": [
                ("Aircrack-ng", "Wi-Fi attacks", self.run_aircrack, "aircrack-ng -b <BSSID>", "aircrack-ng"),
                ("Wifite", "Wi-Fi automation", self.run_wifite, "wifite", "wifite"),
            ],
            "Password Cracking": [
                ("John", "Password cracking", self.run_john, "john hash.txt", "john"),
                ("Hydra", "Brute force attacks", self.run_hydra, "hydra -l user -P passlist.txt ssh://192.168.1.1", "hydra"),
            ],
            "Anonymity": [
                ("Proxychains", "Proxy usage", self.run_proxychains, "proxychains nmap 192.168.1.1", "proxychains"),
                ("TorGhost", "Tor routing", self.run_torghost, "torghost --start", "torghost"),
            ],
            "Monitoring": [
                ("Wireshark", "Packet sniffing", self.run_wireshark, "wireshark", "wireshark"),
                ("Htop", "System monitoring", self.run_htop, "htop", "htop"),
            ]
        }

        self.tool_inputs = {}
        self.workers = []
        for category, tools in self.tool_categories.items():
            tab = QWidget()
            scroll = QScrollArea()
            scroll.setWidget(tab)
            scroll.setWidgetResizable(True)
            layout = QGridLayout(tab)
            layout.setSpacing(10)
            for i, (name, tooltip, func, default_param, package) in enumerate(tools):
                button = QPushButton(name)
                button.setToolTip(f"{tooltip}\nDefault: {default_param}")
                button.setFont(QFont("Ubuntu Mono", 14))
                button.clicked.connect(lambda checked, f=func, n=name: self.run_tool(f, n))
                button.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
                param_input = QLineEdit()
                param_input.setPlaceholderText(f"e.g., {default_param}")
                param_input.setFont(QFont("Ubuntu Mono", 12))
                param_input.setText(self.settings.value(f"tool_params/{name}", ""))
                self.tool_inputs[name] = param_input
                auto_button = QPushButton("Auto")
                auto_button.clicked.connect(lambda checked, p=param_input, d=default_param: self.auto_fill(p, d))
                layout.addWidget(button, i, 0)
                layout.addWidget(param_input, i, 1)
                layout.addWidget(auto_button, i, 2)
            self.tabs.addTab(scroll, category)

        hacker_menu_button = QPushButton("Hacker Menu")
        hacker_menu_button.setFont(QFont("Ubuntu Mono", 14))
        hacker_menu_button.setObjectName("hackerMenuButton")
        self.hacker_menu = QMenu(self)
        self.hacker_menu.addAction("Restart System", self.restart_system)
        self.hacker_menu.addAction("Shutdown System", self.shutdown_system)
        self.hacker_menu.addAction("Restart App", self.restart_app)
        self.hacker_menu.addAction("Update System", self.update_system)
        self.hacker_menu.addAction("Check Connection", self.check_network)
        self.hacker_menu.addAction("Clear Logs", self.clear_logs)
        self.hacker_menu.addAction("Randomize MAC", self.randomize_mac)
        self.hacker_menu.addAction("Change Hostname", self.change_hostname)
        self.hacker_menu.addAction("Scan Network", self.scan_network)
        self.hacker_menu.addAction("Export Logs", self.export_logs)
        self.hacker_menu.addAction("Import Config", self.import_config)
        self.hacker_menu.addAction("Create Backup", self.create_encrypted_backup)
        self.hacker_menu.addAction("Test DNS Leak", self.test_dns_leak)
        self.hacker_menu.addAction("Schedule Task", self.schedule_task)
        self.hacker_menu.addAction("Auto-Detect Interfaces", self.auto_detect_interfaces)
        self.hacker_menu.addAction("Generate Report", self.generate_report)
        hacker_menu_button.setMenu(self.hacker_menu)
        self.main_layout.addWidget(hacker_menu_button, alignment=Qt.AlignBottom | Qt.AlignRight)

        self.learning_tab = QWidget()
        self.learning_layout = QVBoxLayout(self.learning_tab)
        self.learning_combo = QComboBox()
        self.learning_combo.addItems(["Basics", "Scanning", "Exploits", "Wireless", "Password Cracking", "Anonymity", "Monitoring"])
        self.learning_combo.currentTextChanged.connect(self.update_learning_text)
        self.learning_layout.addWidget(self.learning_combo)
        self.learning_text = QTextEdit()
        self.learning_text.setReadOnly(True)
        self.learning_text.setFont(QFont("Ubuntu Mono", 14))
        self.update_learning_text("Basics")
        self.learning_layout.addWidget(self.learning_text)
        self.tabs.addTab(self.learning_tab, "Learning")

        self.logs_tab = QWidget()
        self.logs_layout = QVBoxLayout(self.logs_tab)
        self.logs_text = QTextEdit()
        self.logs_text.setReadOnly(True)
        self.logs_text.setFont(QFont("Ubuntu Mono", 14))
        self.logs_layout.addWidget(self.logs_text)
        self.tabs.addTab(self.logs_tab, "Logs")

        self.results_tab = QWidget()
        self.results_layout = QVBoxLayout(self.results_tab)
        self.results_splitter = QSplitter(Qt.Horizontal)
        self.results_table = QTableWidget()
        self.results_table.setColumnCount(6)
        self.results_table.setHorizontalHeaderLabels(["Date", "Tool", "Params", "Result", "Status", "Duration"])
        self.results_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.results_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.results_splitter.addWidget(self.results_table)

        self.results_graph_widget = QWidget()
        self.results_graph_layout = QVBoxLayout(self.results_graph_widget)
        self.results_graph_scene = QGraphicsScene()
        self.results_graph = QGraphicsView(self.results_graph_scene)
        self.results_graph.setFixedSize(500, 300)
        self.results_graph_layout.addWidget(self.results_graph)
        self.graph_info_label = QLabel("Click a bar for details")
        self.graph_info_label.setAlignment(Qt.AlignCenter)
        self.results_graph_layout.addWidget(self.graph_info_label)
        self.results_splitter.addWidget(self.results_graph_widget)

        self.date_filter_layout = QHBoxLayout()
        self.start_date = QDateEdit()
        self.start_date.setCalendarPopup(True)
        self.start_date.setDate(QDate.currentDate().addDays(-7))
        self.date_filter_layout.addWidget(QLabel("From:"))
        self.date_filter_layout.addWidget(self.start_date)
        self.end_date = QDateEdit()
        self.end_date.setCalendarPopup(True)
        self.end_date.setDate(QDate.currentDate())
        self.date_filter_layout.addWidget(QLabel("To:"))
        self.date_filter_layout.addWidget(self.end_date)
        self.filter_button = QPushButton("Filter")
        self.filter_button.clicked.connect(self.filter_results_by_date)
        self.date_filter_layout.addWidget(self.filter_button)
        self.results_layout.addLayout(self.date_filter_layout)
        self.results_layout.addWidget(self.results_splitter)
        self.tabs.addTab(self.results_tab, "Results")

        self.anonymity_tab = QWidget()
        self.anonymity_layout = QVBoxLayout(self.anonymity_tab)
        self.ip_label = QLabel("IP: Unknown")
        self.anonymity_layout.addWidget(self.ip_label)
        self.anonymity_report = QTextEdit()
        self.anonymity_report.setReadOnly(True)
        self.anonymity_report.setFont(QFont("Ubuntu Mono", 12))
        self.anonymity_report.setMaximumHeight(100)
        self.anonymity_layout.addWidget(self.anonymity_report)
        check_anonymity_button = QPushButton("Check Anonymity")
        check_anonymity_button.clicked.connect(self.check_anonymity)
        self.anonymity_layout.addWidget(check_anonymity_button)
        self.tabs.addTab(self.anonymity_tab, "Anonymity")

        self.monitoring_tab = QWidget()
        self.monitoring_layout = QVBoxLayout(self.monitoring_tab)
        self.resource_label = QLabel("CPU: N/A | RAM: N/A | Disk: N/A")
        self.monitoring_layout.addWidget(self.resource_label)
        self.refresh_monitor_button = QPushButton("Refresh")
        self.refresh_monitor_button.clicked.connect(self.update_system_resources)
        self.monitoring_layout.addWidget(self.refresh_monitor_button)
        self.tabs.addTab(self.monitoring_tab, "Monitoring")

        self.output_dock = QDockWidget("Output", self)
        self.output_widget = QWidget()
        self.output_layout = QVBoxLayout(self.output_widget)
        self.output = QTextEdit()
        self.output.setReadOnly(True)
        self.output.setFont(QFont("Ubuntu Mono", 14))
        self.output_layout.addWidget(self.output)
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.output_layout.addWidget(self.progress_bar)
        self.output_dock.setWidget(self.output_widget)
        self.addDockWidget(Qt.BottomDockWidgetArea, self.output_dock)

        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Penetration Mode Active | Anonymity: Off", 5000)

        self.vpn_active = False
        self.tor_active = False
        self.proxy_active = False
        self.dns_secure = False
        self.update_status_timer = QTimer()
        self.update_status_timer.timeout.connect(self.update_status)
        self.update_status_timer.start(1000)

        self.scheduled_tasks = {}
        self.task_timer = QTimer()
        self.task_timer.timeout.connect(self.check_scheduled_tasks)
        self.task_timer.start(60000)

        self.auto_update_timer = QTimer()
        if self.yaml_config.get("auto_update", self.settings.value("auto_update", True, type=bool)):
            self.auto_update_timer.timeout.connect(self.check_updates)
            self.auto_update_timer.start(3600000)

        self.update_logging_level()
        self.auto_detect_interfaces()
        self.update_graph()

    def add_toolbar_button(self, icon_name: str, callback, tooltip: str):
        button = QToolButton()
        button.setIcon(QIcon.fromTheme(icon_name))
        button.clicked.connect(callback)
        button.setToolTip(tooltip)
        self.toolbar.addWidget(button)

    def apply_theme(self):
        themes = {
            "Dark": """
                QWidget { background-color: #1C2526; color: #FFFFFF; font-family: 'Ubuntu Mono'; }
                QPushButton, QToolButton { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #2A3439, stop:1 #4A5A66); border: 2px solid #FFFFFF; padding: 10px; font-size: 16px; color: #FFFFFF; border-radius: 8px; }
                QPushButton:hover, QToolButton:hover { background: #4A5A66; }
                QTextEdit, QLineEdit { background-color: #2E2E2E; border: 1px solid #FFFFFF; color: #FFFFFF; font-size: 14px; border-radius: 5px; padding: 5px; }
                QLabel { font-size: 36px; font-weight: bold; color: #FFFFFF; }
                QComboBox { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #2A3439, stop:1 #4A5A66); color: #FFFFFF; padding: 5px; border: 1px solid #FFFFFF; border-radius: 5px; }
                QProgressBar { background-color: #2E2E2E; border: 1px solid #FFFFFF; border-radius: 5px; color: #FFFFFF; }
                QProgressBar::chunk { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #4A5A66, stop:1 #6A8299); }
                QStatusBar { background: #1C2526; color: #FFFFFF; font-size: 14px; }
                QTableWidget { background-color: #2E2E2E; color: #FFFFFF; border: 1px solid #FFFFFF; }
                QDockWidget { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #1C2526, stop:1 #4A5A66); color: #FFFFFF; }
                QPushButton#hackerMenuButton {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #2A3439, stop:1 #4A5A66);
                    border: 1px solid #FFFFFF;
                    padding: 8px 16px;
                    font-size: 14px;
                    color: #FFFFFF;
                    border-radius: 12px;
                    min-width: 120px;
                    min-height: 40px;
                }
                QPushButton#hackerMenuButton:hover {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #4A5A66, stop:1 #6A8299);
                    border: 1px solid #00FFFF;
                }
            """,
            "Light": """
                QWidget { background-color: #F0F0F0; color: #000000; font-family: 'Ubuntu Mono'; }
                QPushButton, QToolButton { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #D0D0D0, stop:1 #B0B0B0); border: 2px solid #000000; padding: 10px; font-size: 16px; color: #000000; border-radius: 8px; }
                QPushButton:hover, QToolButton:hover { background: #B0B0B0; }
                QTextEdit, QLineEdit { background-color: #FFFFFF; border: 1px solid #000000; color: #000000; font-size: 14px; border-radius: 5px; padding: 5px; }
                QLabel { font-size: 36px; font-weight: bold; color: #000000; }
                QComboBox { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #D0D0D0, stop:1 #B0B0B0); color: #000000; padding: 5px; border: 1px solid #000000; border-radius: 5px; }
                QProgressBar { background-color: #FFFFFF; border: 1px solid #000000; border-radius: 5px; color: #000000; }
                QProgressBar::chunk { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #B0B0B0, stop:1 #909090); }
                QStatusBar { background: #F0F0F0; color: #000000; font-size: 14px; }
                QTableWidget { background-color: #FFFFFF; color: #000000; border: 1px solid #000000; }
                QDockWidget { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #F0F0F0, stop:1 #D0D0D0); color: #000000; }
                QPushButton#hackerMenuButton {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #D0D0D0, stop:1 #B0B0B0);
                    border: 1px solid #000000;
                    padding: 8px 16px;
                    font-size: 14px;
                    color: #000000;
                    border-radius: 12px;
                    min-width: 120px;
                    min-height: 40px;
                }
                QPushButton#hackerMenuButton:hover {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #B0B0B0, stop:1 #909090);
                    border: 1px solid #FF0000;
                }
            """,
            "Hacker Green": """
                QWidget { background-color: #0A1F0A; color: #00FF00; font-family: 'Ubuntu Mono'; }
                QPushButton, QToolButton { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #1A3C1A, stop:1 #2A5A2A); border: 2px solid #00FF00; padding: 10px; font-size: 16px; color: #00FF00; border-radius: 8px; }
                QPushButton:hover, QToolButton:hover { background: #2A5A2A; }
                QTextEdit, QLineEdit { background-color: #1A2E1A; border: 1px solid #00FF00; color: #00FF00; font-size: 14px; border-radius: 5px; padding: 5px; }
                QLabel { font-size: 36px; font-weight: bold; color: #00FF00; }
                QComboBox { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #1A3C1A, stop:1 #2A5A2A); color: #00FF00; padding: 5px; border: 1px solid #00FF00; border-radius: 5px; }
                QProgressBar { background-color: #1A2E1A; border: 1px solid #00FF00; border-radius: 5px; color: #00FF00; }
                QProgressBar::chunk { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #2A5A2A, stop:1 #4A7A4A); }
                QStatusBar { background: #0A1F0A; color: #00FF00; font-size: 14px; }
                QTableWidget { background-color: #1A2E1A; color: #00FF00; border: 1px solid #00FF00; }
                QDockWidget { background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #0A1F0A, stop:1 #2A5A2A); color: #00FF00; }
                QPushButton#hackerMenuButton {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #1A3C1A, stop:1 #2A5A2A);
                    border: 1px solid #00FF00;
                    padding: 8px 16px;
                    font-size: 14px;
                    color: #00FF00;
                    border-radius: 12px;
                    min-width: 120px;
                    min-height: 40px;
                }
                QPushButton#hackerMenuButton:hover {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #2A5A2A, stop:1 #4A7A4A);
                    border: 1px solid #FFFFFF;
                }
            """
        }
        self.setStyleSheet(themes.get(self.theme, themes["Dark"]))

    def change_theme(self, theme: str):
        self.theme = theme
        self.settings.setValue("theme", theme)
        self.apply_theme()
        self.update_graph()

    def manage_bluetooth(self):
        dialog = NetworkDialog(self, "Bluetooth")
        dialog.exec_()

    def manage_wifi(self):
        dialog = NetworkDialog(self, "Wi-Fi")
        dialog.exec_()

    def toggle_vpn(self):
        if not self.check_tool("openvpn"):
            self.install_tool("openvpn")
            return
        vpn_path = self.yaml_config.get("vpn_path", self.settings.value("vpn_path", "/etc/openvpn/client.conf"))
        if not os.path.exists(vpn_path):
            self.log_error(f"VPN file {vpn_path} does not exist. Check settings.")
            return
        if not self.vpn_active:
            subprocess.Popen(["pkexec", "openvpn", "--config", vpn_path, "--daemon"])
            self.output.append("VPN activated.")
            self.vpn_active = True
        else:
            try:
                run_with_privileges(["pkill", "openvpn"], timeout=30)
                self.output.append("VPN deactivated.")
                self.vpn_active = False
            except subprocess.CalledProcessError as e:
                self.log_error(f"Failed to deactivate VPN: {str(e)}")
        self.update_status()

    def toggle_tor(self):
        if not self.check_tool("tor"):
            self.install_tool("tor")
            return
        if not self.tor_active:
            try:
                run_with_privileges(["systemctl", "start", "tor"], timeout=30)
                self.output.append("Tor activated.")
                self.tor_active = True
            except subprocess.CalledProcessError as e:
                self.log_error(f"Failed to start Tor: {str(e)}")
        else:
            try:
                run_with_privileges(["systemctl", "stop", "tor"], timeout=30)
                self.output.append("Tor deactivated.")
                self.tor_active = False
            except subprocess.CalledProcessError as e:
                self.log_error(f"Failed to stop Tor: {str(e)}")
        self.update_status()

    def toggle_proxy(self):
        proxy = self.yaml_config.get("proxy", self.settings.value("proxy", "http://localhost:8080"))
        if not self.validate_url(proxy):
            self.log_error(f"Invalid proxy URL: {proxy}")
            return
        if not self.proxy_active:
            os.environ["http_proxy"] = proxy
            os.environ["https_proxy"] = proxy
            self.output.append(f"Proxy activated: {proxy}")
            self.proxy_active = True
        else:
            os.environ.pop("http_proxy", None)
            os.environ.pop("https_proxy", None)
            self.output.append("Proxy deactivated.")
            self.proxy_active = False
        self.update_status()

    def toggle_dns(self):
        dns_servers = self.yaml_config.get("dns_servers", self.settings.value("dns_servers", "8.8.8.8,8.8.4.4")).split(",")
        try:
            if not self.dns_secure:
                dns_content = "\n".join(f"nameserver {server.strip()}" for server in dns_servers)
                with open("/tmp/resolv.conf", "w") as f:
                    f.write(dns_content)
                run_with_privileges(["mv", "/tmp/resolv.conf", "/etc/resolv.conf"])
                self.output.append(f"DNS secured: {', '.join(dns_servers)}")
                self.dns_secure = True
            else:
                with open("/tmp/resolv.conf", "w") as f:
                    f.write("nameserver 127.0.0.1\n")
                run_with_privileges(["mv", "/tmp/resolv.conf", "/etc/resolv.conf"])
                self.output.append("DNS reset to default.")
                self.dns_secure = False
        except subprocess.CalledProcessError as e:
            self.log_error(f"Failed to modify DNS: {str(e)}")
        except PermissionError:
            self.log_error("Permission denied: Cannot modify /etc/resolv.conf")
        self.update_status()

    def toggle_full_anonymity(self):
        if not all([self.vpn_active, self.tor_active, self.proxy_active, self.dns_secure]):
            self.toggle_vpn()
            self.toggle_tor()
            self.toggle_proxy()
            self.toggle_dns()
            self.randomize_mac()
            self.output.append("Full Anonymity mode enabled.")
        else:
            self.toggle_vpn()
            self.toggle_tor()
            self.toggle_proxy()
            self.toggle_dns()
            self.output.append("Full Anonymity mode disabled.")
        self.update_status()

    def check_network(self):
        self.output.append("Checking connection...")
        worker = ProcessWorker(["ping", "-c", "4", "8.8.8.8"], timeout=int(self.settings.value("timeout", 60)))
        worker.output_signal.connect(self.handle_output)
        worker.error_signal.connect(self.handle_error)
        worker.finished_signal.connect(lambda: self.output.append("Check completed."))
        self.workers.append(worker)
        self.threadpool.start(worker)

    def randomize_mac(self):
        if not self.check_tool("macchanger"):
            self.install_tool("macchanger")
            return
        interface = self.yaml_config.get("interface", self.settings.value("interface", "wlan0"))
        try:
            run_with_privileges(["ip", "link", "set", interface, "down"], timeout=30)
            run_with_privileges(["macchanger", "-r", interface], timeout=30)
            run_with_privileges(["ip", "link", "set", interface, "up"], timeout=30)
            self.output.append(f"MAC address randomized for {interface}.")
        except subprocess.CalledProcessError as e:
            self.log_error(f"Failed to randomize MAC: {str(e)}")

    def auto_detect_interfaces(self):
        try:
            result = subprocess.check_output(["ip", "link"], text=True)
            interfaces = [line.split(":")[1].strip() for line in result.splitlines() if "state UP" in line]
            if interfaces:
                self.settings.setValue("interface", interfaces[0])
                self.output.append(f"Auto-detected interface: {interfaces[0]}")
            else:
                self.output.append("No active interfaces detected.")
        except subprocess.CalledProcessError as e:
            self.log_error(f"Interface detection error: {str(e)}")

    def schedule_task(self):
        task_name, ok1 = QInputDialog.getText(self, "Task Name", "Enter task name:")
        if not ok1:
            return
        command, ok2 = QInputDialog.getText(self, "Command", "Enter command to schedule:")
        if not ok2:
            return
        interval, ok3 = QInputDialog.getInt(self, "Interval", "Enter interval in minutes:", 60, 1, 1440)
        if ok3:
            self.scheduled_tasks[task_name] = {"command": command.split(), "interval": interval * 60, "last_run": 0}
            self.output.append(f"Task '{task_name}' scheduled every {interval} minutes.")

    def check_scheduled_tasks(self):
        current_time = datetime.now().timestamp()
        for name, task in list(self.scheduled_tasks.items()):
            if current_time - task["last_run"] >= task["interval"]:
                self.execute_command(task["command"], datetime.now())
                task["last_run"] = current_time
                self.output.append(f"Scheduled task '{name}' executed.")

    def update_system_resources(self):
        try:
            cpu = subprocess.check_output(["top", "-bn1"], text=True).splitlines()[2].split()[1]
            ram = subprocess.check_output(["free", "-h"], text=True).splitlines()[1].split()[2]
            disk = subprocess.check_output(["df", "-h", "/"], text=True).splitlines()[1].split()[3]
            self.resource_label.setText(f"CPU: {cpu}% | RAM: {ram} | Disk: {disk}")
        except subprocess.CalledProcessError as e:
            self.log_error(f"Resource monitoring error: {str(e)}")

    def check_anonymity(self):
        self.tabs.setCurrentWidget(self.anonymity_tab)
        report = []
        try:
            response = requests.get("https://api.ipify.org?format=json", timeout=5)
            ip_info = response.json()
            self.ip_label.setText(f"IP: {ip_info['ip']}")
            detailed_response = requests.get(f"http://ipinfo.io/{ip_info['ip']}/json", timeout=5)
            details = detailed_response.json()
            report.append(f"IP: {ip_info['ip']}")
            report.append(f"Location: {details.get('city', 'Unknown')}, {details.get('region', 'Unknown')}, {details.get('country', 'Unknown')}")
            report.append(f"ISP: {details.get('org', 'Unknown')}")
            dns_result = run_with_privileges(["nslookup", "whoami.akamai.net"], timeout=10).stdout
            report.append(f"DNS Response: {dns_result.strip()}")
            self.anonymity_report.setText("\n".join(report))
            self.output.append(f"Anonymity Report:\n{'-'*20}\n{'\n'.join(report)}\n{'-'*20}")
        except requests.RequestException as e:
            self.log_error(f"IP check error: {str(e)}")
        except subprocess.CalledProcessError as e:
            self.log_error(f"DNS check error: {str(e)}")

    def run_security_scan(self):
        required_tools = ["lynis", "chkrootkit"]
        for tool in required_tools:
            if not self.check_tool(tool):
                self.install_tool(tool)
                return
        self.output.append("Running security scan...")
        self.execute_command(["lynis", "audit", "system"], datetime.now())
        self.execute_command(["chkrootkit"], datetime.now())

    def check_updates(self):
        self.output.append("Checking for updates...")
        try:
            response = requests.get("https://example.com/hackeros_version.json", timeout=10)
            latest_version = response.json().get("version", "unknown")
            current_version = "1.0.0"
            if latest_version != current_version:
                self.output.append(f"Update available: {latest_version}")
                if QMessageBox.question(self, "Update", "Update now?", QMessageBox.Yes | QMessageBox.No) == QMessageBox.Yes:
                    self.update_system()
            else:
                self.output.append("System is up to date.")
        except requests.RequestException as e:
            self.log_error(f"Update check error: {str(e)}")

    def open_settings(self):
        dialog = SettingsDialog(self)
        dialog.exec_()

    def show_help(self):
        QMessageBox.information(self, "Help", """
            **Penetration Mode - HackerOS**
            - Use "Full Anonymity" for one-click privacy.
            - Schedule tasks via "Hacker Menu".
            - Monitor resources in the "Monitoring" tab.
            - Customize themes in the header.
            - All tools run within the GUI.
        """)

    def close_app(self):
        self.save_user_profile()
        for worker in self.workers[:]:
            if worker.isRunning():
                worker.terminate()
        QApplication.quit()

    def check_tool(self, tool: str) -> bool:
        try:
            subprocess.run([tool, "--version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False

    def install_tool(self, tool: str):
        self.output.append(f"Installing {tool}...")
        worker = ProcessWorker(["apt-get", "install", "-y", tool], timeout=300)
        worker.output_signal.connect(self.handle_output)
        worker.error_signal.connect(self.handle_error)
        worker.finished_signal.connect(self.process_finished)
        self.workers.append(worker)
        self.threadpool.start(worker)

    def execute_command(self, command: List[str], start_time: datetime):
        worker = ProcessWorker(command, timeout=int(self.settings.value("timeout", 60)))
        worker.output_signal.connect(lambda data: self.handle_output(data, start_time))
        worker.error_signal.connect(lambda data: self.handle_error(data, start_time))
        worker.finished_signal.connect(self.process_finished)
        worker.progress_signal.connect(self.update_progress)
        self.workers.append(worker)
        self.threadpool.start(worker)

    def run_nmap(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("nmap"):
            self.install_tool("nmap")
            return
        self.execute_command(["nmap"] + params.split(), start_time)

    def run_masscan(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("masscan"):
            self.install_tool("masscan")
            return
        self.execute_command(["masscan"] + params.split(), start_time)

    def run_openvas(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("openvas-start"):
            self.install_tool("openvas")
            return
        self.execute_command(["openvas-start"], start_time)

    def run_metasploit(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("msfconsole"):
            self.install_tool("metasploit-framework")
            return
        self.execute_command(["msfconsole"] + params.split(), start_time)

    def run_sqlmap(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("sqlmap"):
            self.install_tool("sqlmap")
            return
        self.execute_command(["sqlmap"] + params.split(), start_time)

    def run_aircrack(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("aircrack-ng"):
            self.install_tool("aircrack-ng")
            return
        self.execute_command(["aircrack-ng"] + params.split(), start_time)

    def run_wifite(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("wifite"):
            self.install_tool("wifite")
            return
        self.execute_command(["wifite"] + params.split(), start_time)

    def run_john(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("john"):
            self.install_tool("john")
            return
        self.execute_command(["john"] + params.split(), start_time)

    def run_hydra(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("hydra"):
            self.install_tool("hydra")
            return
        self.execute_command(["hydra"] + params.split(), start_time)

    def run_proxychains(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("proxychains"):
            self.install_tool("proxychains")
            return
        self.execute_command(["proxychains"] + params.split(), start_time)

    def run_torghost(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("torghost"):
            self.install_tool("torghost")
            return
        self.execute_command(["torghost"] + params.split(), start_time)

    def run_wireshark(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("wireshark"):
            self.install_tool("wireshark")
            return
        self.execute_command(["wireshark"] + params.split(), start_time)

    def run_htop(self, params: str, tool_name: str, start_time: datetime):
        if not self.check_tool("htop"):
            self.install_tool("htop")
            return
        self.execute_command(["htop"] + params.split(), start_time)

    def restart_system(self):
        if QMessageBox.question(self, "Restart", "Restart system now?", QMessageBox.Yes | QMessageBox.No) == QMessageBox.Yes:
            try:
                run_with_privileges(["reboot"], timeout=10)
            except subprocess.CalledProcessError as e:
                self.log_error(f"Failed to restart system: {str(e)}")

    def shutdown_system(self):
        if QMessageBox.question(self, "Shutdown", "Shutdown system now?", QMessageBox.Yes | QMessageBox.No) == QMessageBox.Yes:
            try:
                run_with_privileges(["poweroff"], timeout=10)
            except subprocess.CalledProcessError as e:
                self.log_error(f"Failed to shutdown system: {str(e)}")

    def restart_app(self):
        self.save_user_profile()
        python = sys.executable
        os.execl(python, python, *sys.argv)

    def update_system(self):
        self.output.append("Updating system...")
        worker = ProcessWorker(["apt-get", "update", "&&", "apt-get", "upgrade", "-y"], timeout=600)
        worker.output_signal.connect(self.handle_output)
        worker.error_signal.connect(self.handle_error)
        worker.finished_signal.connect(self.process_finished)
        self.workers.append(worker)
        self.threadpool.start(worker)

    def change_hostname(self):
        new_hostname, ok = QInputDialog.getText(self, "Change Hostname", "Enter new hostname:")
        if ok and new_hostname:
            try:
                run_with_privileges(["hostnamectl", "set-hostname", new_hostname], timeout=30)
                self.output.append(f"Hostname changed to {new_hostname}")
            except subprocess.CalledProcessError as e:
                self.log_error(f"Failed to change hostname: {str(e)}")

    def scan_network(self):
        if not self.check_tool("nmap"):
            self.install_tool("nmap")
            return
        self.output.append("Scanning network...")
        self.execute_command(["nmap", "-sn", "192.168.1.0/24"], datetime.now())

    def export_logs(self):
        export_path, _ = QFileDialog.getSaveFileName(self, "Export Logs", "", "Text Files (*.txt)")
        if export_path:
            try:
                with open(export_path, "w") as f:
                    f.write(self.logs_text.toPlainText())
                self.output.append(f"Logs exported to {export_path}")
            except IOError as e:
                self.log_error(f"Failed to export logs: {str(e)}")

    def import_config(self):
        import_path, _ = QFileDialog.getOpenFileName(self, "Import Config", "", "YAML Files (*.yaml)")
        if import_path:
            try:
                with open(import_path, "r") as f:
                    config = yaml.safe_load(f)
                for key, value in config.items():
                    self.settings.setValue(key, value)
                self.output.append(f"Config imported from {import_path}")
                self.yaml_config = load_yaml_config()
            except (yaml.YAMLError, IOError) as e:
                self.log_error(f"Failed to import config: {str(e)}")

    def create_encrypted_backup(self):
        backup_path, _ = QFileDialog.getSaveFileName(self, "Save Backup", "", "Encrypted Files (*.enc)")
        if backup_path:
            try:
                profile_data = json.dumps(self.user_profile).encode()
                encrypted_data = self.cipher_suite.encrypt(profile_data)
                with open(backup_path, "wb") as f:
                    f.write(encrypted_data)
                self.output.append(f"Encrypted backup created at {backup_path}")
            except Exception as e:
                self.log_error(f"Failed to create backup: {str(e)}")

    def test_dns_leak(self):
        self.output.append("Testing DNS leak...")
        worker = ProcessWorker(["nslookup", "whoami.akamai.net"], timeout=10)
        worker.output_signal.connect(self.handle_output)
        worker.error_signal.connect(self.handle_error)
        worker.finished_signal.connect(self.process_finished)
        self.workers.append(worker)
        self.threadpool.start(worker)

    def run_tool(self, func, tool_name: str):
        params = self.tool_inputs[tool_name].text().strip()
        if not self.validate_input(params):
            self.output.append(f"Error: Invalid parameters for {tool_name}.")
            return
        self.settings.setValue(f"tool_params/{tool_name}", params)
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(0)
        start_time = datetime.now()
        func(params, tool_name, start_time)

    def validate_input(self, params: str) -> bool:
        dangerous = ["rm -rf", "dd", "mkfs", ":(){ :|:& };:", "chmod -R", "chown -R", "kill -9", "reboot", "shutdown"]
        return not any(d in params.lower() for d in dangerous)

    def validate_url(self, url: str) -> bool:
        try:
            result = urlparse(url)
            return all([result.scheme, result.netloc])
        except ValueError:
            return False

    def update_logging_level(self):
        level = self.yaml_config.get("log_level", self.settings.value("log_level", "INFO"))
        logging.getLogger().setLevel(getattr(logging, level))

    def update_encryption_key(self, new_key: str):
        self.encryption_key = new_key
        self.cipher_suite = Fernet(generate_key(self.encryption_key))
        self.output.append("Encryption key updated.")

    def log_info(self, message: str):
        encrypted_message = self.cipher_suite.encrypt(message.encode()).decode()
        self.logs_text.append(encrypted_message)
        logging.info(message)

    def log_error(self, message: str):
        encrypted_message = self.cipher_suite.encrypt(message.encode()).decode()
        self.logs_text.append(encrypted_message)
        self.output.append(f"Error: {message}")
        logging.error(message)

    def handle_output(self, data: str, start_time: datetime = None):
        self.output.append(data)
        self.log_info(data)
        row = self.results_table.rowCount()
        self.results_table.insertRow(row)
        cmd = self.sender().command if self.sender() else []
        duration = (datetime.now() - start_time).total_seconds() if start_time else 0
        self.results_table.setItem(row, 0, QTableWidgetItem(datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
        self.results_table.setItem(row, 1, QTableWidgetItem(cmd[0] if cmd else "Unknown"))
        self.results_table.setItem(row, 2, QTableWidgetItem(" ".join(cmd[1:]) if len(cmd) > 1 else ""))
        self.results_table.setItem(row, 3, QTableWidgetItem(data[:100] + "..." if len(data) > 100 else data))
        self.results_table.setItem(row, 4, QTableWidgetItem("Success"))
        self.results_table.setItem(row, 5, QTableWidgetItem(f"{duration:.2f}s"))
        self.update_graph()

    def handle_error(self, data: str, start_time: datetime = None):
        self.log_error(f"Error: {data}")
        row = self.results_table.rowCount()
        self.results_table.insertRow(row)
        cmd = self.sender().command if self.sender() else []
        duration = (datetime.now() - start_time).total_seconds() if start_time else 0
        self.results_table.setItem(row, 0, QTableWidgetItem(datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
        self.results_table.setItem(row, 1, QTableWidgetItem(cmd[0] if cmd else "Unknown"))
        self.results_table.setItem(row, 2, QTableWidgetItem(" ".join(cmd[1:]) if len(cmd) > 1 else ""))
        self.results_table.setItem(row, 3, QTableWidgetItem(data[:100] + "..." if len(data) > 100 else data))
        self.results_table.setItem(row, 4, QTableWidgetItem("Error"))
        self.results_table.setItem(row, 5, QTableWidgetItem(f"{duration:.2f}s"))
        self.update_graph()

    def process_finished(self):
        self.output.append("Process completed.")
        self.progress_bar.setVisible(False)
        self.workers = [w for w in self.workers if not w.isFinished()]

    def update_progress(self, value: int):
        self.progress_bar.setValue(value)

    def auto_fill(self, param_input: QLineEdit, default_param: str):
        if not param_input.text():
            param_input.setText(default_param)
        self.output.append(f"Auto parameters set: {default_param}")

    def clear_logs(self):
        self.logs_text.clear()
        self.results_table.setRowCount(0)
        self.results_graph_scene.clear()
        self.graph_info_label.setText("Click a bar for details")
        self.output.append("Logs and results cleared.")

    def update_status(self):
        status = "Penetration Mode Active | Anonymity: "
        components = []
        if self.vpn_active:
            components.append("VPN")
        if self.tor_active:
            components.append("Tor")
        if self.proxy_active:
            components.append("Proxy")
        if self.dns_secure:
            components.append("DNS")
        status += " + ".join(components) if components else "Off"
        status += f" | Threads: {self.threadpool.activeThreadCount()} | Tasks: {len(self.scheduled_tasks)}"
        self.status_bar.showMessage(status)

    def update_learning_text(self, topic: str):
        learning_content = {
            "Basics": "Welcome to HackerOS! Start by exploring tools and settings.",
            "Scanning": "Use Nmap or Masscan to discover devices and open ports.",
            "Exploits": "Metasploit and Sqlmap help test vulnerabilities.",
            "Wireless": "Aircrack-ng and Wifite target Wi-Fi networks.",
            "Password Cracking": "John and Hydra crack passwords efficiently.",
            "Anonymity": "Proxychains and TorGhost enhance privacy.",
            "Monitoring": "Wireshark and Htop monitor network and system."
        }
        self.learning_text.setText(learning_content.get(topic, "Select a topic to learn more."))

    def update_graph(self):
        self.results_graph_scene.clear()
        tools = [self.results_table.item(i, 1).text() for i in range(self.results_table.rowCount()) if self.results_table.item(i, 1)]
        counts = {tool: tools.count(tool) for tool in set(tools)}
        if not counts:
            self.results_graph_scene.addText("No data available", QFont("Ubuntu Mono", 14)).setPos(200, 140)
            return

        bar_width = 50
        spacing = 20
        max_height = 250
        max_count = max(counts.values()) if counts else 1
        x_start = 50
        y_bottom = 280

        self.results_graph_scene.addText("Tool Usage", QFont("Ubuntu Mono", 14)).setPos(200, 10)
        self.results_graph_scene.addLine(50, y_bottom, 450, y_bottom, QPen(Qt.white))
        self.results_graph_scene.addLine(50, 30, 50, y_bottom, QPen(Qt.white))

        for i, (tool, count) in enumerate(counts.items()):
            x = x_start + i * (bar_width + spacing)
            height = (count / max_count) * max_height
            bar = self.results_graph_scene.addRect(x, y_bottom - height, bar_width, height, QPen(Qt.NoPen), QBrush(QColor("#4A5A66")))
            bar.setData(1, tool)
            bar.setFlag(QGraphicsItem.ItemIsSelectable, True)
            self.results_graph_scene.addText(tool, QFont("Ubuntu Mono", 10)).setPos(x + bar_width // 2 - 20, y_bottom + 5)
            self.results_graph_scene.addText(str(count), QFont("Ubuntu Mono", 10)).setPos(x + bar_width // 2 - 10, y_bottom - height - 15)

        self.results_graph.mousePressEvent = self.on_graph_click

    def on_graph_click(self, event):
        pos = event.scenePos()
        item = self.results_graph_scene.itemAt(pos, self.results_graph.transform())
        if item and isinstance(item, QGraphicsRectItem):
            tool_name = item.data(1)
            results = [f"{self.results_table.item(i, 0).text()} - {self.results_table.item(i, 3).text()} ({self.results_table.item(i, 5).text()})"
                       for i in range(self.results_table.rowCount())
                       if self.results_table.item(i, 1).text() == tool_name]
            self.graph_info_label.setText(f"{tool_name}: {len(results)} runs\n" + "\n".join(results[:3]))
            QMessageBox.information(self, f"{tool_name} Details", "\n".join(results))

    def filter_results_by_date(self):
        start = self.start_date.date().toPyDate()
        end = self.end_date.date().toPyDate()
        self.results_table.setRowCount(0)
        for entry in self.user_profile["history"]:
            date = datetime.strptime(entry["date"], "%Y-%m-%d %H:%M:%S").date()
            if start <= date <= end:
                row = self.results_table.rowCount()
                self.results_table.insertRow(row)
                self.results_table.setItem(row, 0, QTableWidgetItem(entry["date"]))
                self.results_table.setItem(row, 1, QTableWidgetItem(entry["tool"]))
                self.results_table.setItem(row, 2, QTableWidgetItem(entry["params"]))
                self.results_table.setItem(row, 3, QTableWidgetItem(entry.get("result", "N/A")))
                self.results_table.setItem(row, 4, QTableWidgetItem(entry.get("status", "Unknown")))
                self.results_table.setItem(row, 5, QTableWidgetItem(entry.get("duration", "0.00s")))
        self.update_graph()

    def load_user_profile(self) -> Dict:
        profile_path = Path.home() / f".hackeros_profile_{self.yaml_config.get('profile_name', self.settings.value('profile_name', 'default_user'))}.json"
        if profile_path.exists():
            try:
                with open(profile_path, "r") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                self.log_error(f"Profile load error: {str(e)}")
        return {"history": [], "preferences": {}}

    def save_user_profile(self):
        profile_path = Path.home() / f".hackeros_profile_{self.yaml_config.get('profile_name', self.settings.value('profile_name', 'default_user'))}.json"
        max_history = int(self.yaml_config.get("history_size", self.settings.value("history_size", 100)))
        self.user_profile["history"] = [
            {"tool": self.results_table.item(i, 1).text(), "params": self.results_table.item(i, 2).text(),
             "date": self.results_table.item(i, 0).text(), "result": self.results_table.item(i, 3).text(),
             "status": self.results_table.item(i, 4).text(), "duration": self.results_table.item(i, 5).text()}
            for i in range(self.results_table.rowCount())
        ][-max_history:]
        self.user_profile["preferences"] = {"theme": self.theme}
        try:
            with open(profile_path, "w") as f:
                json.dump(self.user_profile, f, indent=2)
        except IOError as e:
            self.log_error(f"Profile save error: {str(e)}")

    def generate_report(self):
        report_path, _ = QFileDialog.getSaveFileName(self, "Save Report", "", "Text Files (*.txt)")
        if report_path:
            try:
                with open(report_path, "w") as f:
                    f.write(f"HackerOS Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                    f.write(f"Profile: {self.settings.value('profile_name', 'default_user')}\n")
                    f.write("-" * 50 + "\n")
                    f.write("Anonymity Status:\n")
                    f.write(f"VPN: {'Active' if self.vpn_active else 'Inactive'}\n")
                    f.write(f"Tor: {'Active' if self.tor_active else 'Inactive'}\n")
                    f.write(f"Proxy: {'Active' if self.proxy_active else 'Inactive'}\n")
                    f.write(f"DNS: {'Secure' if self.dns_secure else 'Default'}\n")
                    f.write("-" * 50 + "\n")
                    f.write("Recent Activity:\n")
                    for i in range(min(5, self.results_table.rowCount())):
                        f.write(f"{self.results_table.item(i, 0).text()} | {self.results_table.item(i, 1).text()} | "
                                f"{self.results_table.item(i, 3).text()} | {self.results_table.item(i, 4).text()}\n")
                self.output.append(f"Report saved to {report_path}")
            except IOError as e:
                self.log_error(f"Failed to save report: {str(e)}")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = PenetrationModeWindow()
    window.show()
    sys.exit(app.exec_())
