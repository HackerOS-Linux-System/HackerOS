const fs = require('fs');
const os = require('os');

let lang = 'en';

const translations = {
    'en': {
        'title': 'Hacker Mode',
        'settings': 'Settings',
        'hacker_menu': 'Hacker Menu',
        'steam': 'Steam',
        'heroic': 'Heroic',
        'hyperplay': 'HyperPlay',
        'lutris': 'Lutris',
        'audio': 'Audio',
        'increase_volume': 'Increase Volume',
        'decrease_volume': 'Decrease Volume',
        'toggle_mute': 'Toggle Mute',
        'display': 'Display',
        'increase_brightness': 'Increase Brightness',
        'decrease_brightness': 'Decrease Brightness',
        'toggle_theme': 'Toggle Dark/Light Mode',
        'network': 'Network',
        'wifi_settings': 'Wi-Fi Settings',
        'toggle_wifi': 'Toggle Wi-Fi',
        'bluetooth': 'Bluetooth',
        'power': 'Power',
        'power_saving': 'Power Saving',
        'balanced': 'Balanced',
        'performance': 'Performance',
        'general': 'General',
        'app_not_installed': 'To install missing applications, use the package manager.',
        'launch_cooldown': 'Please wait {seconds} seconds before launching {app} again.',
        'no_internet': 'No internet connection. Please enable Wi-Fi.',
        'wifi_list': 'Available Wi-Fi Networks',
        'connect': 'Connect',
        'bluetooth_devices': 'Bluetooth Devices',
        'scan': 'Scan',
        'pair': 'Pair',
        'no_networks': 'No networks found',
        'connection_failed': 'Connection failed: {error}',
        'connecting': 'Connecting to {ssid}...',
        'wifi_toggle_success': 'Wi-Fi turned {state}',
        'wifi_toggle_failed': 'Failed to toggle Wi-Fi: {error}',
        'no_selection': 'Please select an item',
        'pairing': 'Pairing {device}...',
        'pairing_failed': 'Pairing failed: {error}',
        'switch_plasma': 'Switch to Plasma',
        'shutdown': 'Shutdown',
        'restart': 'Restart',
        'sleep': 'Sleep',
        'restart_apps': 'Restart Apps',
        'log_out': 'Log Out',
        'restart_sway': 'Restart Sway',
        'close': 'Close',
        'back': 'Back'
    },
    'pl': {
        'title': 'Tryb Hakera',
        'settings': 'Ustawienia',
        'hacker_menu': 'Menu Hakera',
        'steam': 'Steam',
        'heroic': 'Heroic',
        'hyperplay': 'HyperPlay',
        'lutris': 'Lutris',
        'audio': 'Dźwięk',
        'increase_volume': 'Zwiększ głośność',
        'decrease_volume': 'Zmniejsz głośność',
        'toggle_mute': 'Wycisz/Włącz dźwięk',
        'display': 'Wyświetlacz',
        'increase_brightness': 'Zwiększ jasność',
        'decrease_brightness': 'Zmniejsz jasność',
        'toggle_theme': 'Przełącz tryb ciemny/jasny',
        'network': 'Sieć',
        'wifi_settings': 'Ustawienia Wi-Fi',
        'toggle_wifi': 'Włącz/Wyłącz Wi-Fi',
        'bluetooth': 'Bluetooth',
        'power': 'Zasilanie',
        'power_saving': 'Oszczędzanie energii',
        'balanced': 'Zrównoważony',
        'performance': 'Wydajność',
        'general': 'Ogólne',
        'app_not_installed': 'Aby zainstalować brakujące aplikacje, użyj menedżera pakietów.',
        'launch_cooldown': 'Proszę czekać {seconds} sekund przed ponownym uruchomieniem {app}.',
        'no_internet': 'Brak połączenia z internetem. Proszę włączyć Wi-Fi.',
        'wifi_list': 'Dostępne sieci Wi-Fi',
        'connect': 'Połącz',
        'bluetooth_devices': 'Urządzenia Bluetooth',
        'scan': 'Skanuj',
        'pair': 'Paruj',
        'no_networks': 'Nie znaleziono sieci',
        'connection_failed': 'Połączenie nieudane: {error}',
        'connecting': 'Łączenie z {ssid}...',
        'wifi_toggle_success': 'Wi-Fi przełączone na {state}',
        'wifi_toggle_failed': 'Nie udało się przełączyć Wi-Fi: {error}',
        'no_selection': 'Proszę wybrać element',
        'pairing': 'Parowanie {device}...',
        'pairing_failed': 'Parowanie nieudane: {error}',
        'switch_plasma': 'Przełącz na Plasma',
        'shutdown': 'Wyłącz',
        'restart': 'Uruchom ponownie',
        'sleep': 'Uśpij',
        'restart_apps': 'Restartuj aplikacje',
        'log_out': 'Wyloguj',
        'restart_sway': 'Restartuj sesję Sway',
        'close': 'Zamknij',
        'back': 'Wróć'
    }
};

function setupLanguage() {
    try {
        const locale = os.locale || process.env.LANG || 'en_US';
        lang = locale.split('_')[0];
        if (!translations[lang]) lang = 'en';
        log(`Language set to: ${lang}`);
    } catch (e) {
        log(`Error setting language: ${e}`, 'error');
        lang = 'en';
    }
    return lang;
}

function setLanguage(newLang) {
    if (translations[newLang]) {
        lang = newLang;
        log(`Language changed to: ${newLang}`, 'info');
    }
}

function getText(key, params = {}) {
    let text = translations[lang][key] || key;
    for (const [k, v] of Object.entries(params)) {
        text = text.replace(`{${k}}`, v);
    }
    return text;
}

function log(message, level = 'info') {
    const logMessage = `${new Date().toISOString()} - ${level.toUpperCase()} - ${message}\n`;
    fs.appendFileSync('/tmp/hacker-mode.log', logMessage);
}

module.exports = { setupLanguage, setLanguage, getText };
