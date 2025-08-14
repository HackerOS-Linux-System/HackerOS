# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

autoload -Uz compinit
compinit
zstyle ':completion:*' menu select


echo -ne "🔐 Loading terminal"
for i in {1..3}; do echo -ne "."; sleep 0.2; done
clear



# HackerOS-Welcome
cat << "EOF"
┌───[ H A C K E R O S ]──────────────────────────────────────────────┐
│                                                                    │
│ ██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗██████╗  ██████╗ ███████╗  │
│ ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗██╔═══██╗██╔════╝  │
│ ███████║███████║██║     █████╔╝ █████╗  ██████╔╝██║   ██║███████╗  │
│ ██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗██║   ██║╚════██║  │
│ ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║╚██████╔╝███████║  │
│ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝  │
│                                                                    │
└───[ SYSTEM READY ]─────────────────────────────────────────────────┘

       ══════════════════════════════════════════════════
       ║      W E L C O M E   T O   H A C K E R O S     ║
       ║                   v2.7                         ║
       ══════════════════════════════════════════════════

┗┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┛
> Secure, fast, game-ready. Updates done. You decide.
> Welcome aboard, operator — HackerOS Team
┗┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┉┛

[ NETWORK LINKS ]
┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
Website:  https://hackeros.webnode.page
Discord:  https://discord.gg/8yHNcBaEKy
X:        https://x.com/hackeros_linux
GitHub:   https://github.com/HackerOS-Linux-System/
Reddit:   https://www.reddit.com/r/HackerOS/
┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅

[ SYSTEM COMMANDS ]
┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
Command                    | Description
---------------------------+----------------------------------------
hacker-unpack             | Installs tools for gaming, cybersecurity, add-ons, and development
hacker-commands           | Displays list of available commands
hacker-update             | Updates the system
hacker-addons             | Installs various add-ons
hacker-devtools           | Installs development tools
hacker-unpack-gaming      | Installs gaming tools
┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
EOF



#Custom-Commands


#hacker-unpack
alias hacker-unpack="&& hacker-unpack-cybersecurity && hacker-unpack-gaming && hacker-devtools && hacker-add-ons"

alias hacker-unpack-cybersecurity="hacker-update && echo ========== Penetration Tools Install ========== && sudo hacker install nmap wireshark nikto john hydra aircrack-ng sqlmap ettercap-text-only tcpdump zmap bettercap wfuzz hashcat fail2ban rkhunter chkrootkit lynis clamav tor proxychains4 httrack sublist3r macchanger inxi htop openvas openvpn && echo ========== Install Metasploit Framework ========== && sudo snap install metasploit-framework && echo ========== Install Ghidra ========== && flatpak install flathub org.ghidra_sre.Ghidra && echo ========== Hacker-Unpack-Cybersecurity Compl3te =========="

alias hacker-unpack-gaming="hacker-update && echo ========== Install OBS STUDIO and LUTRIS ========== && sudo hacker install obs-studio lutris && echo ========== STEAM installation ========== && sudo hacker install steam && echo ========== Pika Torrent installation ========== && flatpak install flathub com.pikatorrent.PikaTorrent && echo ========== Install Heroic Games Launcher ProtonTricks and Discord ========== && flatpak install flathub net.davidotek.pupgui2 && flatpak install heroicgameslauncher protontricks discord && echo ========== Install Roblox ========== && flatpak install --user https://sober.vinegarhq.org/sober.flatpakref && echo ========== Install Roblox Studio ========== flatpak install flathub org.vinegarhq.Vinegar && echo ========== Hacker-Unpack-Gaming Complete =========="

alias hacker-unpack-gaming-noroblox="hacker-update && echo ========== Install OBS STUDIO and LUTRIS ========== && sudo hacker install obs-studio lutris && echo ========== STEAM installation ========== && sudo apt install steam && echo ========== Pika Torrent installation ========== && flatpak install flathub com.pikatorrent.PikaTorrent && echo ========== Install Heroic Games Launcher ProtonTricks and Discord ========== && flatpak install flathub net.davidotek.pupgui2 && flatpak install heroicgameslauncher protontricks discord && echo ========== Hacker-Unpack-Gaming-NoRoblox Complete =========="

alias hacker-unpack-emulators="hacker-update && echo ========== Install PlayStation Emulator ========== flatpak install shadPS4 && echo ========== Install Emulator Nintendo ========== && flatpak install flathub io.github.ryubing.Ryujinx && echo ========== Install DOSBOX ========== && flatpak install flathub com.dosbox_x.DOSBox-X && echo ========== Install PlayStation 3 Emulator ========== && sudo snap install rpcs3-emu && echo ========== Hacker-Unpack-Emulators Complete =========="

alias hacker-mode-install="echo Updating System && hacker-update && flathub install heroicgameslauncher && flatpak install --user https://sober.vinegarhq.org/sober.flatpakref && flatpak install flathub xyz.hyperplay.HyperPlay && sudo hacker install lutris steam"

#hacker install gamescope steam
alias hacker-install-gamescope-steam="/usr/share/HackerOS/Scripts/Bin/hacker-install-gamescope-steam.sh"

#Hacker-SysLogs
alias hacker-syslog="echo ========== System Logs ========== && sudo journalctl -xe"

#Lista Komend
alias hacker-commands="echo ========== Commands List ==========  hacker-update hacker-unpack hacker-unpack-cybersecurity hacker-unpack-gaming hacker-unpack-gaming-noroblox hacker-syslogs hacker-unpack-emulators && echo ========== Instead of the sudo apt command you can use hacker =========="

#Hacker-DevTools
alias hacker-devtools="hacker-update && echo ========== Install Atom ========== && flatpak install flathub io.atom.Atom && echo ========== Install Dev Tools Complete =========="

#Hacker-AddOns
alias hacker-add-ons="hacker-update && echo ========== Install Wine ========== && sudo hacker install wine winetricks && echo ========== Install BoxBuddy and Winezgui ========== && flatpak install flathub io.github.dvlv.boxbuddyrs && flatpak install winezgui && flatpak install flathub it.mijorus.gearlever && echo ========== Install Add-Ons Complete =========="

#hacker-nvidia-akmod
alias nvidia-akmod="hacker-update && sudo hacker install nvidia-akmod"

#hacker-unpack-g-s
alias hacker-unpack-g-s="hacker-update && hacker-unpack-gaming && hacker-unpack-cybersecurity"

#Star-HackerOS-Cockpit
alias start-hackeros-cockpit="python3 /usr/share/HackerOS/Scripts/HackerOS-Apps/HackerOS-Cockpit/HackerOS_Cockpit.py"

# 🔥 Dark Mode dla Basha w Alacritty
export LS_COLORS="di=1;34:ln=1;36:so=1;35:pi=1;33:ex=1;32"

# 🔥 Ustawienia kolorów dla terminala
export PS1="\[\e[1;37m\]\u@\h:\[\e[1;34m\]\w\[\e[0m\]$ "

# 🎨 Funkcja do wyświetlania kolorowych klikalnych linków
function link() {
    local text="$1"
    local url="$2"
    echo -e "\e[1;31m\e]8;;$url\a$text\e]8;;\a\e[0m"
}

# 🌍 Funkcja do otwierania linków w domyślnej przeglądarce
function openlink() {
    local url="$1"
    if command -v xdg-open >/dev/null; then
        xdg-open "$url" >/dev/null 2>&1 &
    elif command -v gnome-open >/dev/null; then
        gnome-open "$url" >/dev/null 2>&1 &
    elif command -v open >/dev/null; then
        open "$url" >/dev/null 2>&1 &  # macOS
    else
        echo "❌ Nie można otworzyć linku: $url"
    fi
}


# Kolory dla ls
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'

# Emoji + git
alias gs='echo 🌀 && git status'
alias gc='echo 📦 && git commit -m'
alias gp='echo ⬆️ && git push'

# Kolorowe PS1 (jeśli nie używasz Starship)
PS1='\[\e[1;32m\]\u@\h \[\e[1;34m\]\w \[\e[0;33m\]$\[\e[0m\] '

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=5000

# Ignoruj duplikaty w historii
setopt HIST_IGNORE_DUPS

# Włącz “menu completion” – wybór z listy TAB
setopt MENU_COMPLETE
