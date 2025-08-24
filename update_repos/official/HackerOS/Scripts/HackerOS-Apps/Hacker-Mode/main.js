const { app, BrowserWindow, ipcMain } = require('electron');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { setMainWindow } = require('./launchers');
const { setWindows } = require('./settings');
const { setupLanguage, getText } = require('./utils');

let mainWindow, settingsWindow;

function log(message, level = 'info') {
    const logMessage = `${new Date().toISOString()} - ${level.toUpperCase()} - ${message}\n`;
    fs.appendFileSync('/tmp/hacker-mode.log', logMessage);
}

function createWindow() {
    mainWindow = new BrowserWindow({
        fullscreen: true,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        },
        backgroundColor: '#1A1A1A'
    });

    mainWindow.loadFile('index.html').catch(e => log(`Error loading index.html: ${e}`, 'error'));
    mainWindow.on('closed', () => {
        mainWindow = null;
        if (settingsWindow) settingsWindow.close();
    });

        setMainWindow(mainWindow);
        setWindows(mainWindow, settingsWindow);

        mainWindow.webContents.on('did-finish-load', () => {
            mainWindow.webContents.executeJavaScript(`
            document.getElementById('title').innerText = '${getText('title')}';
            document.getElementById('settings-btn').innerText = '${getText('settings')}';
            document.getElementById('hacker-menu-btn').innerText = '${getText('hacker_menu')}';
            gsap.from('.launcher-btn', { duration: 1, y: 50, opacity: 0, stagger: 0.2 });
            gsap.from('#logo', { duration: 1.5, scale: 0, ease: 'elastic' });
            `).catch(e => log(`Error executing JavaScript in main window: ${e}`, 'error'));
        });

        require('child_process').exec('swaymsg fullscreen enable', (err) => {
            if (err) log(`Error setting fullscreen: ${err}`, 'error');
        });
}

function createSettingsWindow() {
    if (!mainWindow) return; // Prevent creating settings if main window is closed
    mainWindow.hide(); // Hide main window when opening settings
    settingsWindow = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        },
        backgroundColor: '#1A1A1A',
        parent: mainWindow,
        modal: true
    });

    settingsWindow.loadFile('settings.html').catch(e => log(`Error loading settings.html: ${e}`, 'error'));
    settingsWindow.on('closed', () => {
        settingsWindow = null;
        if (mainWindow) mainWindow.show(); // Show main window when settings is closed
    });

        setWindows(mainWindow, settingsWindow);

        settingsWindow.webContents.on('did-finish-load', () => {
            settingsWindow.webContents.executeJavaScript(`
            document.getElementById('settings-title').innerText = '${getText('settings')}';
            document.getElementById('language-select').value = '${setupLanguage()}';
            document.getElementById('audio-title').innerText = '${getText('audio')}';
            document.getElementById('display-title').innerText = '${getText('display')}';
            document.getElementById('network-title').innerText = '${getText('network')}';
            document.getElementById('power-title').innerText = '${getText('power')}';
            document.getElementById('general-title').innerText = '${getText('general')}';
            document.getElementById('wifi-title').innerText = '${getText('wifi_settings')}';
            document.getElementById('bluetooth-title').innerText = '${getText('bluetooth')}';
            document.querySelector('.back-btn').innerText = '${getText('back')}';
            document.querySelector('.close-btn').innerText = '${getText('close')}';
            gsap.from('.setting-panel', { duration: 1, y: 50, opacity: 0, stagger: 0.2 });
            `).catch(e => log(`Error executing JavaScript in settings window: ${e}`, 'error'));
        });
}

app.whenReady().then(() => {
    setupLanguage();
    createWindow();
    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
}).catch(e => log(`Error during app startup: ${e}`, 'error'));

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

ipcMain.handle('launchSettings', async () => {
    log('Launching settings', 'info');
    if (!settingsWindow && mainWindow) createSettingsWindow();
});

ipcMain.handle('closeSettings', async () => {
    log('Closing settings', 'info');
    if (settingsWindow) {
        settingsWindow.close();
        if (mainWindow) mainWindow.show(); // Ensure main window is shown when settings is closed
    }
});

ipcMain.handle('initSettings', async () => {
    log('Initializing settings', 'info');
    if (settingsWindow) {
        settingsWindow.webContents.executeJavaScript(`
        document.querySelectorAll('button[onclick*="audioAction"]').forEach(btn => {
            if (btn.innerText.includes('Increase')) btn.innerText = '${getText('increase_volume')}';
            else if (btn.innerText.includes('Decrease')) btn.innerText = '${getText('decrease_volume')}';
            else if (btn.innerText.includes('Toggle')) btn.innerText = '${getText('toggle_mute')}';
        });
        document.querySelectorAll('button[onclick*="displayAction"]').forEach(btn => {
            if (btn.innerText.includes('Increase')) btn.innerText = '${getText('increase_brightness')}';
            else if (btn.innerText.includes('Decrease')) btn.innerText = '${getText('decrease_brightness')}';
            else if (btn.innerText.includes('Toggle')) btn.innerText = '${getText('toggle_theme')}';
        });
        document.querySelectorAll('button[onclick*="networkAction"]').forEach(btn => {
            if (btn.innerText.includes('Wi-Fi Settings')) btn.innerText = '${getText('wifi_settings')}';
            else if (btn.innerText.includes('Toggle')) btn.innerText = '${getText('toggle_wifi')}';
            else if (btn.innerText.includes('Bluetooth')) btn.innerText = '${getText('bluetooth')}';
        });
        document.querySelectorAll('button[onclick*="powerAction"]').forEach(btn => {
            if (btn.innerText.includes('Power Saving')) btn.innerText = '${getText('power_saving')}';
            else if (btn.innerText.includes('Balanced')) btn.innerText = '${getText('balanced')}';
            else if (btn.innerText.includes('Performance')) btn.innerText = '${getText('performance')}';
        });
        document.querySelector('button[onclick*="closeSettings"]').innerText = '${getText('close')}';
        document.querySelector('button[onclick*="connectWifi"]').innerText = '${getText('connect')}';
        document.querySelector('button[onclick*="scanBluetooth"]').innerText = '${getText('scan')}';
        document.querySelector('button[onclick*="pairBluetooth"]').innerText = '${getText('pair')}';
        `).catch(e => log(`Error initializing settings: ${e}`, 'error'));
    }
});
