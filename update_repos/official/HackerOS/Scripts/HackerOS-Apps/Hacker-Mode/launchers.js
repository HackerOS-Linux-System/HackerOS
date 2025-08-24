const { ipcMain } = require('electron');
const { exec, spawn } = require('child_process');
const util = require('util');
const fs = require('fs');
const { getText } = require('./utils');
const execPromise = util.promisify(exec);

let mainWindow;
let runningProcesses = [];
const lastLaunchTimes = {};

function log(message, level = 'info') {
    const logMessage = `${new Date().toISOString()} - ${level.toUpperCase()} - ${message}\n`;
    fs.appendFileSync('/tmp/hacker-mode.log', logMessage);
}

function setMainWindow(win) {
    mainWindow = win;
}

async function checkAppInstalled(command, appName) {
    try {
        if (command.includes('flatpak')) {
            const flatpakId = command[2];
            const { stdout } = await execPromise('flatpak list --app --columns=application');
            const installedApps = stdout.split('\n').map(app => app.trim()).filter(app => app);
            if (!installedApps.includes(flatpakId)) {
                mainWindow.webContents.executeJavaScript(`alert('${getText('app_not_installed')}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
                log(`${appName} not installed`, 'error');
                return false;
            }
            return true;
        } else {
            const { stdout } = await execPromise(`which ${command[0]}`);
            if (!stdout) {
                mainWindow.webContents.executeJavaScript(`alert('${getText('app_not_installed')}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
                log(`${appName} not installed`, 'error');
                return false;
            }
            return true;
        }
    } catch (e) {
        log(`Error checking if ${appName} is installed: ${e}`, 'error');
        mainWindow.webContents.executeJavaScript(`alert('${getText('app_not_installed')}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        return false;
    }
}

async function checkInternet() {
    try {
        const { stdout } = await execPromise('nmcli networking connectivity');
        if (stdout.trim() === 'full') return true;
        const { stdout: ping } = await execPromise('ping -c 1 8.8.8.8');
        if (ping) return true;
        return false;
    } catch (e) {
        log(`Error checking internet: ${e}`, 'error');
        return false;
    }
}

async function setFullscreen(appId, appName, retries = 3, delay = 3000) {
    for (let i = 0; i < retries; i++) {
        try {
            // Try setting fullscreen using app_id or class
            await execPromise(`swaymsg '[app_id="${appId}" title=".*${appName}.*"] fullscreen enable'`);
            log(`Set fullscreen for ${appName} (app_id: ${appId})`, 'info');
            return true;
        } catch (err) {
            log(`Attempt ${i + 1} failed to set fullscreen for ${appName}: ${err}`, 'error');
            if (i < retries - 1) {
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }
    log(`Failed to set fullscreen for ${appName} after ${retries} attempts`, 'error');
    return false;
}

ipcMain.handle('launchApp', async (event, appName) => {
    const currentTime = Date.now() / 1000;
    const lastLaunch = lastLaunchTimes[appName] || 0;
    const cooldownSeconds = 60;

    if (currentTime - lastLaunch < cooldownSeconds) {
        const remaining = Math.ceil(cooldownSeconds - (currentTime - lastLaunch));
        mainWindow.webContents.executeJavaScript(`alert('${getText('launch_cooldown', { app: appName, seconds: remaining })}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        log(`Launch blocked for ${appName} due to cooldown: ${remaining}s`, 'info');
        return;
    }

    const apps = {
        'steam': { command: ['flatpak', 'run', 'com.valvesoftware.Steam', '-gamepadui'], flatpak: true, requiresInternet: true, appId: 'com.valvesoftware.Steam' },
        'heroic': { command: ['flatpak', 'run', 'com.heroicgameslauncher.hgl'], flatpak: true, requiresInternet: true, appId: 'com.heroicgameslauncher.hgl' },
        'hyperplay': { command: ['flatpak', 'run', 'xyz.hyperplay.HyperPlay'], flatpak: true, requiresInternet: true, appId: 'xyz.hyperplay.HyperPlay' },
        'lutris': { command: ['lutris'], flatpak: false, requiresInternet: false, appId: 'lutris' }
    };

    const app = apps[appName];
    if (!app) {
        log(`Unknown app: ${appName}`, 'error');
        return;
    }

    if (!(await checkAppInstalled(app.command, appName))) {
        return;
    }

    if (app.requiresInternet && !(await checkInternet())) {
        mainWindow.webContents.executeJavaScript(`alert('${getText('no_internet')}');`).catch(e => log(`Error showing alert: ${e}`, 'error'));
        log(`No internet for ${appName}`, 'error');
        return;
    }

    mainWindow.hide();
    log(`Launching ${appName}`, 'info');
    const proc = spawn(app.command[0], app.command.slice(1), {
        env: { ...process.env, XDG_SESSION_TYPE: 'wayland' },
        detached: true,
        stdio: 'ignore'
    });

    runningProcesses.push([appName, proc]);
    lastLaunchTimes[appName] = currentTime;

    setTimeout(async () => {
        const appId = app.flatpak ? app.command[2] : app.command[0].split('/').pop();
        // First focus the application
        try {
            await execPromise(`swaymsg '[app_id="${appId}" title=".*${appName}.*"] focus'`);
            log(`Focused ${appName} (app_id: ${appId})`, 'info');
        } catch (err) {
            log(`Error focusing ${appName}: ${err}`, 'error');
        }
        // Then attempt to set fullscreen with retries
        await setFullscreen(appId, appName);
    }, 3000);

    proc.on('close', () => {
        log(`${appName} closed`, 'info');
        runningProcesses = runningProcesses.filter(([name, p]) => p.pid !== proc.pid);
        if (mainWindow) {
            mainWindow.show();
            exec('swaymsg fullscreen enable', (err) => {
                if (err) log(`Error restoring fullscreen for Hacker Mode: ${err}`, 'error');
            });
        }
    });
});

ipcMain.handle('systemAction', async (event, action) => {
    const actions = {
        switchToPlasma: () => {
            log('Switching to Plasma', 'info');
            exec('systemctl start plasma-kde', (err) => {
                if (err) log(`Error switching to Plasma: ${err}`, 'error');
            });
        },
        shutdown: () => {
            log('Shutting down', 'info');
            exec('systemctl poweroff', (err) => {
                if (err) log(`Error shutting down: ${err}`, 'error');
            });
        },
        restart: () => {
            log('Restarting', 'info');
            exec('systemctl reboot', (err) => {
                if (err) log(`Error restarting: ${err}`, 'error');
            });
        },
        sleep: () => {
            log('Suspending', 'info');
            exec('systemctl suspend', (err) => {
                if (err) log(`Error suspending: ${err}`, 'error');
            });
        },
        restartApps: () => {
            log('Restarting apps', 'info');
            ['steam', 'heroic', 'hyperplay', 'lutris'].forEach(app => {
                exec(`pkill -f ${app}`, (err) => {
                    if (err) log(`Error killing ${app}: ${err}`, 'error');
                });
            });
            runningProcesses = [];
            if (mainWindow) {
                mainWindow.show();
                exec('swaymsg fullscreen enable', (err) => {
                    if (err) log(`Error restoring fullscreen: ${err}`, 'error');
                });
            }
        },
        logout: () => {
            log('Logging out', 'info');
            exec('swaymsg exit', (err) => {
                if (err) log(`Error logging out: ${err}`, 'error');
            });
        },
        restartSway: () => {
            log('Restarting Sway', 'info');
            exec('swaymsg reload', (err) => {
                if (err) log(`Error restarting Sway: ${err}`, 'error');
            });
        }
    };

    if (actions[action]) actions[action]();
});

module.exports = { setMainWindow };
