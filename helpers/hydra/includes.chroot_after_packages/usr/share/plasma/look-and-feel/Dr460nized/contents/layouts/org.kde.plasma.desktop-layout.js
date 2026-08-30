var plasma = getApiVersion(1)

// Center Krunner on screen - requires relogin
const krunner = ConfigFile('krunnerrc')
krunner.group = 'General'
krunner.writeEntry('FreeFloating', true);

// Change keyboard repeat delay from default 600ms to 250ms
const kbd = ConfigFile('kcminputrc')
kbd.group = 'Keyboard'
kbd.writeEntry('RepeatDelay', 250);


// Create Top Panel //
loadTemplate("org.garuda.desktop.defaultPanel")

// Create Bottom Panel (Dock) //
loadTemplate("org.garuda.desktop.defaultDock")


// Apply Wallpaper Active Blur plugin to all Desktops of the current Activity
var allDesktops = desktops();
for (i=0;i<allDesktops.length;i++){
  d = allDesktops[i];
  d.wallpaperPlugin = "a2n.blur";
  d.currentConfigGroup = Array("Wallpaper", "a2n.blur", "General");
}