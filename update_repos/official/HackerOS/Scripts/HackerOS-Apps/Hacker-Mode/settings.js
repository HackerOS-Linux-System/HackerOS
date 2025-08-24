const { ipcMain } = require('electron');
const { exec } = require('child_process');
const util = require('util');
const fs = require('fs');
const path = require('path');
const { getText } = require('./utils');
const execPromise = util.promisify(exec);

let mainWindow, settingsWindow;
let isDarkMode = true;
let isMuted = false;
let wifiEnabled = true;

function log(message, level = 'info') {
    const logMessage = `${new Date().toISOString()} - ${level.toUpperCase()} - ${message}\n`;
    fs.appendFileSync('/tmp/hacker-mode.log', logMessage);
}

function setWindows(main, settings) {
    mainWindow = main;
    settingsWindow = settings;
}

ipcMain.handle('audioAction', async (event, action) => {
    const actions = {
        increaseVolume: () => {
            log('Increasing volume', 'info');
            isMuted = false;
            exec('pactl set-sink-volume @DEFAULT_SINK@ +5%', (err) => {
                if (err) log(`Error increasing volume: ${err}`, 'error');
            });
        },
        decreaseVolume: () => {
            log('Decreasing volume', 'info');
            isMuted = false;
            exec('pactl set-sink-volume @DEFAULT_SINK@ -5%', (err) => {
                if (err) log(`Error decreasing volume: ${err}`, 'error');
            });
        },
        toggleMute: () => {
            log('Toggling mute', 'info');
            isMuted = !isMuted;
            exec('pactl set-sink-mute @DEFAULT_SINK@ toggle', (err) => {
                if (err) log(`Error toggling mute: ${err}`, 'error');
            });
        }
    };

    if (actions[action]) actions[action]();
});

ipcMain.handle('displayAction', async (event, action) => {
    const actions = {
        increaseBrightness: () => {
            log('Increasing brightness', 'info');
            exec('brightnessctl set +5%', (err) => {
                if (err) log(`Error increasing brightness: ${err}`, 'error');
            });
        },
        decreaseBrightness: () => {
            log('Decreasing brightness', 'info');
            exec('brightnessctl set 5%-', (err) => {
                if (err) log(`Error decreasing brightness: ${err}`, 'error');
            });
        },
        toggleTheme: () => {
            log('Toggling theme', 'info');
            isDarkMode = !isDarkMode;
            const theme = isDarkMode ? 'dark' : 'light';
            const configPath = path.join(require('os').homedir(), '.config/sway/config');
            try {
                let config = fs.readFileSync(configPath, 'utf8');
                config = config.replace(/set \$theme (dark|light)/, `set $theme ${theme}`);
                fs.writeFileSync(configPath, config);
                exec('swaymsg reload', (err) => {
                    if (err) log(`Error reloading Sway: ${err}`, 'error');
                });
            } catch (e) {
                log(`Error toggling theme: ${e}`, 'error');
            }
        }
    };

    if (actions[action]) actions[action]();
});

ipcMain.handle('networkAction', async (event, action) => {
    const actions = {
        showWifiSettings: () => {
            log('Showing Wi-Fi settings', 'info');
            settingsWindow.webContents.executeJavaScript(`
            document.getElementById('wifi-panel').classList.remove('hidden');
            document.getElementById('bluetooth-panel').classList.add('hidden');
            document.getElementById('wifi-list').innerHTML = '';
            `).catch(e => log(`Error showing Wi-Fi settings: ${e}`, 'error'));
            exec('nmcli -t -f SSID,SIGNAL dev wifi', (err, stdout) => {
                if (err) {
                    log(`Error scanning Wi-Fi: ${err}`, 'error');
                    settingsWindow.webContents.executeJavaScript(`document.getElementById('wifi-list').innerHTML = '<p>${getText('no_networks')}</p>';`).catch(e => log(`Error updating Wi-Fi list: ${e}`, 'error'));
                    return;
                }
                const networks = stdout.split('\n').filter(line => line).map(line => {
                    const [ssid, signal] = line.split(':');
                    return { ssid, signal };
                });
                if (!networks.length) {
                    settingsWindow.webContents.executeJavaScript(`document.getElementById('wifi-list').innerHTML = '<p>${getText('no_networks')}</p>';`).catch(e => log(`Error updating Wi-Fi list: ${e}`, 'error'));
                    return;
                }
                const networkItems = networks.map(n => `<div class="wifi-item p-2 cursor-pointer" onclick="window.electronApi.selectWifi('${n.ssid}')">${n.ssid} (${n.signal}%)</div>`).join('');
                settingsWindow.webContents.executeJavaScript(`
                document.getElementById('wifi-list').innerHTML = '${networkItems}';
                gsap.from('.wifi-item', { duration: 0.5, y: 20, opacity: 0, stagger: 0.1 });
                `).catch(e => log(`Error updating Wi-Fi list: ${e}`, 'error'));
            });
        },
        toggleWifi: () => {
            log('Toggling Wi-Fi', 'info');
            wifiEnabled = !wifiEnabled;
            const action = wifiEnabled ? 'on' : 'off';
            exec(`nmcli radio wifi ${action}`, (err, stdout, stderr) => {
                if (err) {
                    log(`Error toggling Wi-Fi: ${err}`, 'error');
                    settingsWindow.webContents.executeJavaScript(`alert('${getText('wifi_toggle_failed', { error: stderr })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
                    return;
                }
                settingsWindow.webContents.executeJavaScript(`alert('${getText('wifi_toggle_success', { state: action })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
            });
        },
        showBluetooth: () => {
            log('Showing Bluetooth', 'info');
            settingsWindow.webContents.executeJavaScript(`
            document.getElementById('bluetooth-panel').classList.remove('hidden');
            document.getElementById('wifi-panel').classList.add('hidden');
            document.getElementById('bluetooth-list').innerHTML = '';
            `).catch(e => log(`Error showing Bluetooth: ${e}`, 'error'));
        }
    };

    if (actions[action]) actions[action]();
});

ipcMain.handle('powerAction', async (event, profile) => {
    log(`Setting power profile to ${profile}`, 'info');
    exec(`powerprofilesctl set ${profile}`, (err) => {
        if (err) log(`Error setting power profile: ${err}`, 'error');
    });
});

ipcMain.handle('setLanguage', async (event, newLang) => {
    log(`Setting language to ${newLang}`, 'info');
    require('./utils').setLanguage(newLang);
    mainWindow.webContents.executeJavaScript(`
    document.getElementById('title').innerText = '${getText('title')}';
    document.getElementById('settings-btn').innerText = '${getText('settings')}';
    document.getElementById('hacker-menu-btn').innerText = '${getText('hacker_menu')}';
    `).catch(e => log(`Error updating main window: ${e}`, 'error'));
    if (settingsWindow) {
        settingsWindow.webContents.executeJavaScript(`
        document.getElementById('settings-title').innerText = '${getText('settings')}';
        document.getElementById('language-select').value = '${newLang}';
        document.getElementById('audio-title').innerText = '${getText('audio')}';
        document.getElementById('display-title').innerText = '${getText('display')}';
        document.getElementById('network-title').innerText = '${getText('network')}';
        document.getElementById('power-title').innerText = '${getText('power')}';
        document.getElementById('general-title').innerText = '${getText('general')}';
        document.getElementById('wifi-title').innerText = '${getText('wifi_settings')}';
        document.getElementById('bluetooth-title').innerText = '${getText('bluetooth')}';
        document.querySelector('.back-btn').innerText = '${getText('back')}';
        document.querySelector('.close-btn').innerText = '${getText('close')}';
        `).catch(e => log(`Error updating settings window: ${e}`, 'error'));
    }
});

ipcMain.handle('selectWifi', async (event, ssid) => {
    settingsWindow.webContents.executeJavaScript(`
    window.selectedWifi = '${ssid}';
    document.querySelectorAll('.wifi-item').forEach(item => item.classList.remove('bg-gray-600'));
    document.querySelector(\`.wifi-item[onclick="window.electronApi.selectWifi('${ssid}')"]\`).classList.add('bg-gray-600');
    `).catch(e => log(`Error selecting Wi-Fi: ${e}`, 'error'));
});

ipcMain.handle('connectWifi', async () => {
    log('Connecting to Wi-Fi', 'info');
    const ssid = await settingsWindow.webContents.executeJavaScript(`window.selectedWifi`);
    const password = await settingsWindow.webContents.executeJavaScript(`document.getElementById('wifi-password').value`);
    if (!ssid) {
        settingsWindow.webContents.executeJavaScript(`alert('${getText('no_selection')}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        return;
    }
    try {
        const cmd = password ? `nmcli dev wifi connect "${ssid}" password "${password}"` : `nmcli dev wifi connect "${ssid}"`;
        const { stderr } = await execPromise(cmd);
        if (stderr) {
            settingsWindow.webContents.executeJavaScript(`alert('${getText('connection_failed', { error: stderr })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
            log(`Wi-Fi connection failed: ${stderr}`, 'error');
        } else {
            settingsWindow.webContents.executeJavaScript(`alert('${getText('connecting', { ssid })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        }
    } catch (e) {
        settingsWindow.webContents.executeJavaScript(`alert('${getText('connection_failed', { error: e.message })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        log(`Error connecting to Wi-Fi: ${e}`, 'error');
    }
});

ipcMain.handle('scanBluetooth', async () => {
    log('Scanning Bluetooth', 'info');
    exec('bluetoothctl power on && bluetoothctl scan on && bluetoothctl devices && bluetoothctl scan off', (err, stdout) => {
        if (err) {
            log(`Error scanning Bluetooth: ${err}`, 'error');
            settingsWindow.webContents.executeJavaScript(`document.getElementById('bluetooth-list').innerHTML = '<p>No devices found</p>';`).catch(e => log(`Error updating Bluetooth list: ${e}`, 'error'));
            return;
        }
        const devices = stdout.split('\n').filter(line => line.startsWith('Device')).map(line => {
            const parts = line.split(' ');
            return { id: parts[1], name: parts.slice(2).join(' ') };
        });
        if (!devices.length) {
            settingsWindow.webContents.executeJavaScript(`document.getElementById('bluetooth-list').innerHTML = '<p>No devices found</p>';`).catch(e => log(`Error updating Bluetooth list: ${e}`, 'error'));
            return;
        }
        const deviceItems = devices.map(d => `<div class="bluetooth-item p-2 cursor-pointer" onclick="window.electronApi.selectBluetooth('${d.id}')">${d.name} (${d.id})</div>`).join('');
        settingsWindow.webContents.executeJavaScript(`
        document.getElementById('bluetooth-list').innerHTML = '${deviceItems}';
        gsap.from('.bluetooth-item', { duration: 0.5, y: 20, opacity: 0, stagger: 0.1 });
        `).catch(e => log(`Error updating Bluetooth list: ${e}`, 'error'));
    });
});

ipcMain.handle('selectBluetooth', async (event, deviceId) => {
    settingsWindow.webContents.executeJavaScript(`
    window.selectedBluetooth = '${deviceId}';
    document.querySelectorAll('.bluetooth-item').forEach(item => item.classList.remove('bg-gray-600'));
    document.querySelector(\`.bluetooth-item[onclick="window.electronApi.selectBluetooth('${deviceId}')"]\`).classList.add('bg-gray-600');
    `).catch(e => log(`Error selecting Bluetooth: ${e}`, 'error'));
});

ipcMain.handle('pairBluetooth', async () => {
    log('Pairing Bluetooth', 'info');
    const deviceId = await settingsWindow.webContents.executeJavaScript(`window.selectedBluetooth`);
    if (!deviceId) {
        settingsWindow.webContents.executeJavaScript(`alert('${getText('no_selection')}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        return;
    }
    try {
        const { stderr: pairErr } = await execPromise(`bluetoothctl pair ${deviceId}`);
        if (pairErr) {
            settingsWindow.webContents.executeJavaScript(`alert('${getText('pairing_failed', { error: pairErr })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
            log(`Bluetooth pairing failed: ${pairErr}`, 'error');
            return;
        }
        const { stderr: connectErr } = await execPromise(`bluetoothctl connect ${deviceId}`);
        if (connectErr) {
            settingsWindow.webContents.executeJavaScript(`alert('${getText('pairing_failed', { error: connectErr })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
            log(`Bluetooth connection failed: ${connectErr}`, 'error');
        } else {
            settingsWindow.webContents.executeJavaScript(`alert('${getText('pairing', { device: deviceId })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        }
    } catch (e) {
        settingsWindow.webContents.executeJavaScript(`alert('${getText('pairing_failed', { error: e.message })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        log(`Error pairing Bluetooth: ${e}`, 'error');
    }
});

module.exports = { setWindows };
