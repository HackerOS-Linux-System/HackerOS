const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronApi', {
    launchApp: (appName) => ipcRenderer.invoke('launchApp', appName),
                                systemAction: (action) => ipcRenderer.invoke('systemAction', action),
                                launchSettings: () => ipcRenderer.invoke('launchSettings'),
                                audioAction: (action) => ipcRenderer.invoke('audioAction', action),
                                displayAction: (action) => ipcRenderer.invoke('displayAction', action),
                                networkAction: (action) => ipcRenderer.invoke('networkAction', action),
                                powerAction: (profile) => ipcRenderer.invoke('powerAction', profile),
                                setLanguage: (newLang) => ipcRenderer.invoke('setLanguage', newLang),
                                selectWifi: (ssid) => ipcRenderer.invoke('selectWifi', ssid),
                                connectWifi: () => ipcRenderer.invoke('connectWifi'),
                                scanBluetooth: () => ipcRenderer.invoke('scanBluetooth'),
                                selectBluetooth: (deviceId) => ipcRenderer.invoke('selectBluetooth', deviceId),
                                pairBluetooth: () => ipcRenderer.invoke('pairBluetooth'),
                                closeSettings: () => ipcRenderer.invoke('closeSettings'),
                                initSettings: () => ipcRenderer.invoke('initSettings')
});
