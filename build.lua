#!/usr/bin/env lua5.5

-- =====================================================================
-- FUNKCJE POMOCNICZE
-- =====================================================================

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Wykonuje polecenie powłoki. Przerywa działanie skryptu w razie błędu,
-- chyba że allow_fail == true (wtedy zwraca false i tylko ostrzega).
local function sh(cmd, allow_fail)
    io.write("+ " .. cmd .. "\n")
    local ok = os.execute(cmd)
    if ok == true or ok == 0 then
        return true
    end
    if allow_fail then
        io.stderr:write("Ostrzeżenie: polecenie nie powiodło się (kontynuuję): " .. cmd .. "\n")
        return false
    end
    io.stderr:write("Błąd: polecenie nie powiodło się: " .. cmd .. "\n")
    os.exit(1)
end

local function capture(cmd)
    local h = io.popen(cmd)
    if not h then
        io.stderr:write("Błąd: nie udało się uruchomić: " .. cmd .. "\n")
        os.exit(1)
    end
    local out = h:read("*a") or ""
    h:close()
    return (out:gsub("%s+$", ""))
end

local function exists(path)
    return os.execute("test -e " .. quote(path)) == true
end

local function isdir(path)
    return os.execute("test -d " .. quote(path)) == true
end

local function mkdirp(path)
    sh("mkdir -p " .. quote(path))
end

local function rmrf(path)
    sh("rm -rf " .. quote(path))
end

local function download(url, dest)
    sh("curl -fL -o " .. quote(dest) .. " " .. quote(url))
end

local function chmodx(path)
    sh("chmod +x " .. quote(path))
end

local function chmodx_if_exists(path)
    if exists(path) then
        chmodx(path)
    else
        io.stderr:write("Ostrzeżenie: plik nie istnieje, pomijam chmod: " .. path .. "\n")
    end
end

local function clone(url, dest, depth)
    rmrf(dest)
    sh("git clone --depth " .. tostring(depth or 1) .. " " .. quote(url) .. " " .. quote(dest))
end

local function heading(text)
    io.write("\n=== " .. text .. " ===\n")
end

-- =====================================================================
-- WERSJE APLIKACJI
-- =====================================================================

-- Kategoria: HackerOS-Apps
local VER_STORE    = "v0.6"
local VER_LAUNCHER = "v1.0"
local VER_PROTON   = "v0.0.1"
local VER_TERM     = "v0.8"
local VER_WELCOME  = "v0.6"

-- Kategoria: /usr/bin
local VER_CLI    = "v2.4.2"
local VER_NIX    = "v0.1"
local VER_LANG   = "gen-1"
local VER_HPM    = "v0.9"
local VER_CHKER  = "v0.1"
local VER_GETIT  = "v0.4"
local VER_STEAM  = "v0.4"
local VER_HSH    = "v0.4"
local VER_NGT    = "v0.4"
local VER_HEDIT  = "v0.5"

-- Kategoria: HackerOS-Games
local VER_GAMES  = "v0.8"

-- Kategoria: gaming-cli (edycja --gaming)
local VER_GAMING = "v0.2"

-- Kategoria: hammer (edycja --atomic)
local VER_HAMMER = "v0.5.0"

-- =====================================================================
-- ŚCIEŻKI DOCELOWE
-- =====================================================================

local TARGET_SHARE       = "config/includes.chroot_after_packages/usr/share"
local TARGET_APPS        = TARGET_SHARE .. "/HackerOS/Scripts/HackerOS-Apps"
local TARGET_BIN         = "config/includes.chroot_after_packages/usr/bin"
local REPO_TMP           = "/tmp/HackerOS-Updates"

local APPLICATIONS_DIR   = TARGET_SHARE .. "/applications"
local STEAM_BIN_DIR      = TARGET_SHARE .. "/HackerOS/Scripts/Steam/bin"
local GAMES_DIR          = TARGET_SHARE .. "/HackerOS/Scripts/HackerOS-Games"

local ETC_SKEL           = "config/includes.chroot_after_packages/etc/skel"
local HACKEROS_SKEL      = ETC_SKEL .. "/.hackeros"
local HACKER_SKEL_DIR    = HACKEROS_SKEL .. "/hacker"
local HNM_SKEL_DIR       = HACKEROS_SKEL .. "/hnm"

local USR_LIB            = "config/includes.chroot_after_packages/usr/lib"
local USR_LOCAL_BIN      = "config/includes.chroot_after_packages/usr/local/bin"
local USR_LIBEXEC        = "config/includes.chroot_after_packages/usr/libexec"
local ETC_HAMMER_DIR     = "config/includes.chroot_after_packages/etc/hammer"

local PACKAGES_CHROOT    = "config/packages.chroot"

local LANG_TMP           = "/tmp/Hacker-Lang"
local HAMMER_TMP         = "/tmp/HackerOS-Hammer"

local CONFIG_DIR         = "config"
local GAMING_HELPERS_SRC = "helpers/gaming"

-- =====================================================================
-- DEFINICJE EDYCJI (FLAG WIERSZA POLECEŃ)
-- =====================================================================
-- Każda edycja to jedna flaga --nazwa.
--
-- Pola:
--   build_script - skrypt Lua uruchamiany na końcu zamiast domyślnego
--                   build/build-hackeros (jeśli nie podano, używany jest
--                   domyślny skrypt).
--   placeholder  - jeśli true, edycja nie ma jeszcze własnej logiki i
--                   zachowuje się jak build domyślny (z informacją w logu).
--   pre_build    - nazwa dodatkowego kroku (funkcji) wykonywanego po
--                   wszystkich standardowych krokach, a przed
--                   uruchomieniem skryptu budującego. Klucz odnosi się do
--                   wpisu w tabeli EDITION_PRE_BUILD zdefiniowanej niżej.

local EDITIONS = {
    gaming = {
        build_script = "build/build-hackeros-gaming",
        placeholder  = false,
    },
    blue = {
        build_script = "build/build-hackeros-blue",
        placeholder  = false,
    },
    hwde = {
        build_script = "build/build-hackeros-hwde",
        placeholder  = false,
    },
    hydra = {
        build_script = "build/build-hackeros-hydra",
        placeholder  = false,
        pre_build    = "hydra",
    },
    lts = {
        build_script = "build/build-hackeros-lts",
        placeholder  = false,
        pre_build    = "lts",
    },
    gnome = {
        build_script = "build/build-hackeros",
        placeholder  = false,
        pre_build    = "gnome",
    },
    xfce = {
        build_script = "build/build-hackeros-xfce",
        placeholder  = false,
        pre_build    = "xfce",
    },
    atomic = {
        build_script = "build/build-hackeros",
        placeholder  = false,
        pre_build    = "atomic",
    },
    nvidia = {
        placeholder  = false,
        pre_build    = "nvidia",
    },
    -- Edycje cybersecurity / cybersecurity-default nie są budowane na
    -- branchu "official" - ich skrypty budujące (build-hackeros-cybersecurity*)
    -- żyją na branchu "cybersecurity", stąd workflow CI dla tych edycji
    -- checkoutuje osobny branch (patrz .github/workflows/build.yml).
    cybersecurity = {
        build_script = "build/build-hackeros-cybersecurity",
        placeholder  = false,
    },
    ["cybersecurity-default"] = {
        build_script = "build/build-hackeros-cybersecurity-default",
        placeholder  = false,
    },
}

local function print_help()
    io.write([[
Użycie: lua5.5 build.lua [FLAGA]

Bez flagi - standardowy build HackerOS (official).

Dostępne flagi edycji (można podać tylko jedną naraz):
  --gaming                 Edycja gamingowa (helpers/gaming, gaming-cli,
                            build/build-hackeros-gaming, bez HackerOS-Steam)
  --blue                    Edycja Blue (build/build-hackeros-blue)
  --hwde                    Edycja HWDE (build/build-hackeros-hwde)
  --hydra                    Edycja Hydra (helpers/hydra, build/build-hackeros-hydra)
  --lts                      Edycja LTS (helpers/lts, build/build-hackeros-lts)
  --gnome                    Edycja GNOME (helpers/gnome)
  --xfce                     Edycja XFCE (helpers/xfce, build/build-hackeros-xfce)
  --atomic                   Edycja Atomic (Hammer zamiast HackerOS-Store, helpers/atomic)
  --nvidia                   Dodatek NVIDIA (helpers/NVIDIA)
  --cybersecurity            Edycja Cybersecurity (branch cybersecurity,
                              build/build-hackeros-cybersecurity)
  --cybersecurity-default    Edycja Cybersecurity Default (branch cybersecurity,
                              build/build-hackeros-cybersecurity-default)
  --help                     Wyświetla tę pomoc

]])
end

-- Parsuje argumenty wiersza poleceń i zwraca nazwę wybranej edycji
-- (lub nil, jeśli nie podano żadnej flagi).
local function parse_flag(argv)
    local selected = nil
    for i = 1, #argv do
        local a = argv[i]
        local flag = a:match("^%-%-(.+)$")
        if flag == "help" then
            print_help()
            os.exit(0)
        elseif flag then
            if not EDITIONS[flag] then
                io.stderr:write("Błąd: nieznana flaga: --" .. flag .. "\n")
                print_help()
                os.exit(1)
            end
            if selected then
                io.stderr:write("Błąd: można podać tylko jedną flagę edycji naraz (już wybrano --" ..
                                 selected .. ", otrzymano --" .. flag .. ")\n")
                os.exit(1)
            end
            selected = flag
        else
            io.stderr:write("Ostrzeżenie: nieznany argument, ignoruję: " .. a .. "\n")
        end
    end
    return selected
end

-- =====================================================================
-- KROK 1: KLONOWANIE HackerOS-Updates I KOPIOWANIE ZAWARTOŚCI
-- =====================================================================

local function step_clone_updates_repo()
    heading("Klonowanie HackerOS-Updates")
    clone("https://github.com/HackerOS-Linux-System/HackerOS-Updates.git", REPO_TMP)

    mkdirp(TARGET_SHARE)
    mkdirp(TARGET_APPS)
    mkdirp(TARGET_BIN)

    heading("Kopiowanie tapet (wallpaper-updates/wallpapers) i katalogu HackerOS")
    local wallpapers_src = REPO_TMP .. "/wallpaper-updates/wallpapers"
    if isdir(wallpapers_src) then
        -- Kopiujemy cały katalog "wallpapers" (a nie tylko jego zawartość),
        -- żeby w TARGET_SHARE powstał podkatalog usr/share/wallpapers.
        sh("cp -r " .. quote(wallpapers_src) .. " " .. quote(TARGET_SHARE))
    else
        io.write("Ostrzeżenie: Nie znaleziono katalogu " .. wallpapers_src .. "\n")
    end

    if isdir(REPO_TMP .. "/HackerOS") then
        sh("cp -r " .. quote(REPO_TMP .. "/HackerOS") .. " " .. quote(TARGET_SHARE))
    end
end

-- =====================================================================
-- KROK 2: POBIERANIE APLIKACJI DO HackerOS-Apps
-- =====================================================================

local function step_download_apps()
    heading("Pobieranie aplikacji do HackerOS-Apps")

    local apps = {
        { name = "HackerOS-Store",   repo = "HackerOS-Store",     ver = VER_STORE },
        { name = "Hacker_Launcher",  repo = "Hacker_Launcher",    ver = VER_LAUNCHER },
        { name = "proton-manager",   repo = "Proton-Manager",     ver = VER_PROTON },
        { name = "Hacker-Term",      repo = "Hacker-Term",        ver = VER_TERM },
        { name = "HackerOS-Welcome", repo = "HackerOS-Welcome",   ver = VER_WELCOME },
    }

    for _, app in ipairs(apps) do
        local url  = "https://github.com/HackerOS-Linux-System/" .. app.repo ..
                     "/releases/download/" .. app.ver .. "/" .. app.name
        local dest = TARGET_APPS .. "/" .. app.name
        download(url, dest)
        chmodx(dest)
    end
end

-- =====================================================================
-- KROK 3: POBIERANIE NARZĘDZI SYSTEMOWYCH DO /usr/bin
-- =====================================================================

-- W trybie --gaming pomijamy pobieranie hackeros-steam (zastępowanego
-- przez narzędzia gaming-cli).
local function step_download_bin_tools(edition)
    heading("Pobieranie narzędzi systemowych do /usr/bin")

    local tools = {
        { name = "hacker",         repo = "Hacker-CLI-Tool",             ver = VER_CLI },
        { name = "hnm",            repo = "HackerOS-Nix-Manager",        ver = VER_NIX },
        { name = "hl",             repo = "Hacker-Lang",                 ver = VER_LANG },
        { name = "hpm",            repo = "HackerOS-Package-Manager",    ver = VER_HPM },
        { name = "chker",          repo = "chker",                       ver = VER_CHKER },
        { name = "getit",          repo = "getit",                       ver = VER_GETIT },
        { name = "hackeros-steam", repo = "HackerOS-Steam",              ver = VER_STEAM },
        { name = "hsh",            repo = "hsh",                         ver = VER_HSH },
        { name = "ngt",            repo = "ngt",                         ver = VER_NGT },
        { name = "hedit",          repo = "hedit",                       ver = VER_HEDIT },
    }

    for _, tool in ipairs(tools) do
        if edition == "gaming" and tool.name == "hackeros-steam" then
            io.write("Tryb --gaming: pomijam pobieranie " .. tool.name .. "\n")
        else
            local url  = "https://github.com/HackerOS-Linux-System/" .. tool.repo ..
                         "/releases/download/" .. tool.ver .. "/" .. tool.name
            local dest = TARGET_BIN .. "/" .. tool.name
            download(url, dest)
            chmodx(dest)
        end
    end
end

-- =====================================================================
-- KROK 4: ROZPAKOWYWANIE ARCHIWÓW
-- =====================================================================

local function step_extract_archives()
    heading("Rozpakowywanie archiwów")

    -- Uwaga: plik w repozytorium nazywa się "oh-my-zsh.tar.gz" (bez kropki
    -- na początku nazwy), mimo że trafia do katalogu ukrytego .config.
    local zsh_archive = ETC_SKEL .. "/.config/oh-my-zsh.tar.gz"
    if exists(zsh_archive) then
        sh("tar -xzf " .. quote(zsh_archive) .. " -C " .. quote(ETC_SKEL .. "/.config"))
        sh("rm " .. quote(zsh_archive))
    else
        io.write("Ostrzeżenie: Nie znaleziono archiwum " .. zsh_archive .. "\n")
    end

    local icons_archive = TARGET_SHARE .. "/icons.tar.gz"
    if exists(icons_archive) then
        sh("tar -xzf " .. quote(icons_archive) .. " -C " .. quote(TARGET_SHARE))
        sh("rm " .. quote(icons_archive))
    else
        io.write("Ostrzeżenie: Nie znaleziono archiwum " .. icons_archive .. "\n")
    end
end

-- =====================================================================
-- KROK 5: KOPIOWANIE PLIKÓW .desktop
-- =====================================================================

-- Pliki .desktop, które trafiają razem z resztą do APPLICATIONS_DIR, ale
-- mają zostać z niego usunięte (np. bo odpowiadające im aplikacje nie są
-- (jeszcze) częścią tego builda).
local DESKTOP_FILES_TO_REMOVE = {
    "hdev.desktop",
    "HackerOS-Studio.desktop",
    "HackerOS-System-Monitor.desktop",
}

local function step_copy_desktop_files()
    heading("Kopiowanie plików .desktop do usr/share/applications")

    local desktop_src = REPO_TMP .. "/desktop-files"
    if isdir(desktop_src) then
        mkdirp(APPLICATIONS_DIR)
        sh("cp " .. desktop_src .. "/"  .. "*.desktop " .. quote(APPLICATIONS_DIR) ..
           " 2>/dev/null || true", true)
    else
        io.write("Ostrzeżenie: Nie znaleziono katalogu " .. desktop_src .. "\n")
    end

    heading("Usuwanie niechcianych plików .desktop z usr/share/applications")
    for _, name in ipairs(DESKTOP_FILES_TO_REMOVE) do
        local path = APPLICATIONS_DIR .. "/" .. name
        if exists(path) then
            sh("rm -f " .. quote(path))
        else
            io.write("Ostrzeżenie: Nie znaleziono pliku do usunięcia: " .. path .. "\n")
        end
    end
end

-- =====================================================================
-- KROK 6: SPRZĄTANIE KATALOGU TYMCZASOWEGO HackerOS-Updates
-- =====================================================================

local function step_cleanup_updates_repo()
    heading("Czyszczenie katalogu tymczasowego HackerOS-Updates")
    rmrf(REPO_TMP)
end

-- =====================================================================
-- KROK 7: POBIERANIE NAJNOWSZEJ WERSJI VIVALDI
-- =====================================================================

local function step_download_vivaldi()
    heading("Sprawdzanie najnowszej wersji Vivaldi w internecie")

    local url_base = "https://vivaldi.com/download/vivaldi-stable_amd64.deb"
    local url_effective = capture(
        "curl -sIL -o /dev/null -w \"%{url_effective}\" " .. quote(url_base)
    )
    local file_name = url_effective:match("([^/]+)$")
    local target_file = PACKAGES_CHROOT .. "/" .. file_name

    io.write("Najnowszy adres URL: " .. url_effective .. "\n")
    io.write("Docelowy plik: " .. target_file .. "\n")

    if exists(target_file) then
        io.write("Plik " .. file_name .. " już istnieje w " .. PACKAGES_CHROOT .. ". Jest aktualny.\n")
        return
    end

    if isdir(PACKAGES_CHROOT) then
        sh("find " .. quote(PACKAGES_CHROOT) ..
           " -type f -name 'vivaldi-stable*.deb' ! -name " .. quote(file_name) .. " -delete",
           true)
    end

    mkdirp(PACKAGES_CHROOT)

    io.write("Pobieranie najnowszej wersji Vivaldi...\n")
    download(url_effective, target_file)
    io.write("Gotowe! Plik .deb został zapisany w: " .. target_file .. "\n")
end

-- =====================================================================
-- KROK 8: NARZĘDZIA Hacker-CLI-Tool DO ~/.hackeros/hacker
-- =====================================================================

local function step_download_hackeros_hacker_tools()
    heading("Pobieranie narzędzi Hacker-CLI-Tool do .hackeros/hacker")

    mkdirp(HACKER_SKEL_DIR)

    local binaries = {
        "apt-frontend",
        "hacker-docs",
        "hacker-help",
        "hacker-repair",
        "hacker-select",
        "HackerOS-Updater",
        "update-system",
    }

    for _, name in ipairs(binaries) do
        local url  = "https://github.com/HackerOS-Linux-System/Hacker-CLI-Tool/releases/download/" ..
                     VER_CLI .. "/" .. name
        local dest = HACKER_SKEL_DIR .. "/" .. name
        download(url, dest)
        chmodx(dest)
    end
end

-- =====================================================================
-- KROK 9: BINARKI STEAM (gui, tui)
-- =====================================================================

-- W trybie --gaming pomijamy Steam całkowicie (zastępowanego przez
-- narzędzia gaming-cli).
local function step_download_steam_bin(edition)
    if edition == "gaming" then
        heading("Tryb --gaming: pomijam pobieranie binarek Steam (gui, tui)")
        return
    end

    heading("Pobieranie binarek Steam (gui, tui)")

    mkdirp(STEAM_BIN_DIR)

    for _, name in ipairs({ "gui", "tui" }) do
        local url  = "https://github.com/HackerOS-Linux-System/HackerOS-Steam/releases/download/" ..
                     VER_STEAM .. "/" .. name
        local dest = STEAM_BIN_DIR .. "/" .. name
        download(url, dest)
        chmodx(dest)
    end
end

-- =====================================================================
-- KROK 10: BINARKI HackerOS-Games
-- =====================================================================

local function step_download_games()
    heading("Pobieranie binarek HackerOS-Games")

    mkdirp(GAMES_DIR)

    local files = {
        "bark-squadron",
        "bit-jump.love",
        "cosmonaut.love",
        "HackerOS-Games",
        "starblaster",
        "the-racer",
    }

    for _, name in ipairs(files) do
        local url  = "https://github.com/HackerOS-Linux-System/HackerOS-Games/releases/download/" ..
                     VER_GAMES .. "/" .. name
        local dest = GAMES_DIR .. "/" .. name
        download(url, dest)
        chmodx(dest)
    end
end

-- =====================================================================
-- KROK 11: KLON Hacker-Lang -> main-libs oraz bit.lua -> bit
-- =====================================================================

local function step_hacker_lang()
    heading("Klonowanie Hacker-Lang i instalacja main-libs oraz bit")

    clone("https://github.com/HackerOS-Linux-System/Hacker-Lang.git", LANG_TMP)

    local lang_lib_target = USR_LIB .. "/HackerOS/Hacker-Lang"
    mkdirp(lang_lib_target)
    if isdir(LANG_TMP .. "/main-libs") then
        sh("cp -r " .. quote(LANG_TMP .. "/main-libs") .. "/. " .. quote(lang_lib_target))
    else
        io.write("Ostrzeżenie: Nie znaleziono katalogu main-libs w Hacker-Lang\n")
    end

    mkdirp(USR_LOCAL_BIN)
    local bit_src = LANG_TMP .. "/source-code/bit.lua"
    if exists(bit_src) then
        local bit_dest = USR_LOCAL_BIN .. "/bit"
        sh("cp " .. quote(bit_src) .. " " .. quote(bit_dest))
        chmodx(bit_dest)
    else
        io.write("Ostrzeżenie: Nie znaleziono pliku " .. bit_src .. "\n")
    end

    rmrf(LANG_TMP)
end

-- =====================================================================
-- KROK 12: .hackeros/hnm -> version.hacker
-- =====================================================================

local function step_hnm_skel()
    heading("Tworzenie .hackeros/hnm i pobieranie version.hacker")

    mkdirp(HNM_SKEL_DIR)
    -- Uwaga: adres podany jako link do widoku pliku na GitHubie ("blob") nie zwraca
    -- surowej zawartości pliku, dlatego pobieramy z raw.githubusercontent.com.
    local url = "https://raw.githubusercontent.com/HackerOS-Linux-System/HackerOS-Nix-Manager/main/version.hacker"
    download(url, HNM_SKEL_DIR .. "/version.hacker")
end

-- =====================================================================
-- KROK 13: WIRTUALNE ŚRODOWISKO PYTHON W .hackeros
-- =====================================================================

local function step_python_venv()
    heading("Tworzenie venv Python i instalacja pakietów w .hackeros")

    mkdirp(HACKEROS_SKEL)
    sh("cd " .. quote(HACKEROS_SKEL) .. " && python3.13 -m venv venv")

    local pip = HACKEROS_SKEL .. "/venv/bin/pip"

    local packages = {
        "prompt-toolkit",
        "rich",
        "pygments",
        "requests",
        "urllib3",
        "mdurl",
        "markdown-it-py",
        "idna",
        "charset-normalizer",
        "certifi",
    }

    for _, pkg in ipairs(packages) do
        sh(quote(pip) .. " install " .. pkg)
    end
end

-- =====================================================================
-- KROK 14: CHMOD DLA WYBRANYCH PLIKÓW STATYCZNYCH
-- =====================================================================

local function step_chmod_static_files()
    heading("Nadawanie uprawnień wykonywalnych wybranym plikom")

    chmodx_if_exists(USR_LIBEXEC .. "/hackeros-motd")
    chmodx_if_exists(USR_LOCAL_BIN .. "/podhome")
    chmodx_if_exists(USR_LOCAL_BIN .. "/podtemp")
end

-- =====================================================================
-- FUNKCJA POMOCNICZA: KOPIOWANIE KATALOGU helpers/<edycja> DO config/
-- =====================================================================

-- Kopiuje całą zawartość podanego katalogu helperów do config/.
-- use_sudo == true -> polecenie jest poprzedzone "sudo" (zgodnie z
-- wymaganiami niektórych edycji).
local function copy_helper_dir(src, use_sudo)
    heading("Kopiowanie " .. src .. " do config/")

    if isdir(src) then
        mkdirp(CONFIG_DIR)
        local prefix = use_sudo and "sudo " or ""
        sh(prefix .. "cp -r " .. quote(src) .. "/. " .. quote(CONFIG_DIR))
    else
        io.write("Ostrzeżenie: Nie znaleziono katalogu " .. src .. "\n")
    end
end

-- =====================================================================
-- KROK 15 (TYLKO --gaming): KOPIOWANIE helpers/gaming/* DO config/
-- =====================================================================

local function step_copy_gaming_helpers()
    heading("Tryb --gaming: kopiowanie helpers/gaming do config/")
    copy_helper_dir(GAMING_HELPERS_SRC, false)
end

-- =====================================================================
-- KROK 16 (TYLKO --gaming): BINARKI gaming-cli DO /usr/bin
-- =====================================================================

local function step_download_gaming_cli_tools()
    heading("Tryb --gaming: pobieranie binarek gaming-cli do /usr/bin")

    mkdirp(TARGET_BIN)

    local tools = { "gamescope-manager", "gaming", "gaming-cli" }

    for _, name in ipairs(tools) do
        local url  = "https://github.com/HackerOS-Linux-System/gaming-cli/releases/download/" ..
                     VER_GAMING .. "/" .. name
        local dest = TARGET_BIN .. "/" .. name
        download(url, dest)
        chmodx(dest)
    end
end

-- =====================================================================
-- DODATKOWE KROKI PRE-BUILD DLA POSZCZEGÓLNYCH EDYCJI
-- =====================================================================

-- --hydra: kopiowanie helpers/hydra do config/ (bez sudo)
local function step_hydra_pre_build()
    heading("Tryb --hydra: dodatkowe operacje")
    copy_helper_dir("helpers/hydra", false)
end

-- --lts: kopiowanie helpers/lts do config/ (sudo cp -r)
local function step_lts_pre_build()
    heading("Tryb --lts: dodatkowe operacje")
    copy_helper_dir("helpers/lts", true)
end

-- --gnome: kopiowanie helpers/gnome do config/ (sudo cp -r)
local function step_gnome_pre_build()
    heading("Tryb --gnome: dodatkowe operacje")
    copy_helper_dir("helpers/gnome", true)
end

-- --xfce: kopiowanie helpers/xfce do config/ (sudo cp -r)
local function step_xfce_pre_build()
    heading("Tryb --xfce: dodatkowe operacje")
    copy_helper_dir("helpers/xfce", true)
end

-- --nvidia: kopiowanie helpers/NVIDIA do config/ (bez sudo)
local function step_nvidia_pre_build()
    heading("Tryb --nvidia: dodatkowe operacje")
    copy_helper_dir("helpers/NVIDIA", false)
end

-- --atomic: klonowanie hammer i przeniesienie repo-HackerOS do /etc/hammer
local function step_atomic_hammer_repo()
    heading("Tryb --atomic: klonowanie hammer i przenoszenie repo-HackerOS do /etc/hammer")

    clone("https://github.com/HackerOS-Linux-System/hammer.git", HAMMER_TMP)

    local src_dir = HAMMER_TMP .. "/repo-HackerOS"

    if isdir(src_dir) then
        mkdirp(ETC_HAMMER_DIR)
        sh("mv " .. quote(src_dir) .. " " .. quote(ETC_HAMMER_DIR .. "/repo-HackerOS"))
    else
        io.write("Ostrzeżenie: Nie znaleziono katalogu " .. src_dir .. " w sklonowanym repo hammer\n")
    end

    rmrf(HAMMER_TMP)
end

-- --atomic: usunięcie HackerOS-Store.desktop, instalacja Hammer/Hammer-Store,
-- plik .desktop Hammer Store, repo-HackerOS w /etc/hammer, helpers/atomic.
local function step_atomic_pre_build()
    heading("Tryb --atomic: dodatkowe operacje")

    -- Usunięcie HackerOS-Store.desktop (zastępowanego przez Hammer Store)
    local store_desktop = APPLICATIONS_DIR .. "/HackerOS-Store.desktop"
    if exists(store_desktop) then
        sh("rm -f " .. quote(store_desktop))
    else
        io.write("Ostrzeżenie: Nie znaleziono pliku " .. store_desktop .. "\n")
    end

    -- Binarki hammer / hammer-store
    mkdirp(TARGET_BIN)
    for _, name in ipairs({ "hammer", "hammer-store" }) do
        local url  = "https://github.com/HackerOS-Linux-System/hammer/releases/download/" ..
                     VER_HAMMER .. "/" .. name
        local dest = TARGET_BIN .. "/" .. name
        download(url, dest)
        chmodx(dest)
    end

    -- Plik .desktop dla Hammer Store (adres "blob" zamieniony na raw.githubusercontent.com)
    mkdirp(APPLICATIONS_DIR)
    local desktop_url = "https://raw.githubusercontent.com/HackerOS-Linux-System/hammer/main/store/data/org.hackerOS.HammerStore.desktop"
    download(desktop_url, APPLICATIONS_DIR .. "/org.hackerOS.HammerStore.desktop")

    -- repo-HackerOS z klonu hammer -> /etc/hammer
    step_atomic_hammer_repo()

    -- helpers/atomic -> config/
    copy_helper_dir("helpers/atomic", false)
end

-- Tabela dowiązująca klucz pre_build z EDITIONS do konkretnej funkcji.
local EDITION_PRE_BUILD = {
    hydra  = step_hydra_pre_build,
    lts    = step_lts_pre_build,
    gnome  = step_gnome_pre_build,
    xfce   = step_xfce_pre_build,
    nvidia = step_nvidia_pre_build,
    atomic = step_atomic_pre_build,
}

-- =====================================================================
-- KROK 17: URUCHOMIENIE SKRYPTU BUDUJĄCEGO SYSTEM
-- =====================================================================

-- Wybiera skrypt budujący zależnie od edycji: dla edycji w pełni
-- obsługiwanych (np. gaming, blue, hwde, hydra, lts, xfce) używa
-- build_script z EDITIONS; dla edycji placeholder (jeszcze nieobsłużonych)
-- i dla builda domyślnego używa build/build-hackeros.
local function step_run_build(edition)
    local info = edition and EDITIONS[edition]
    local build_script = "build/build-hackeros"

    if info and info.build_script then
        build_script = info.build_script
    elseif info and info.placeholder then
        io.write("Uwaga: flaga --" .. edition ..
                  " jest obecnie placeholderem - dedykowana logika zostanie dodana w przyszłości. " ..
                  "Uruchamiam standardowy build-hackeros.\n")
    end

    heading("Wszystkie operacje plikowe zakończone. Uruchamianie " .. build_script)

    -- Od teraz build/build-hackeros* to skrypty Lua, nie bash - uruchamiamy je
    -- jawnie przez interpreter lua5.5 (shebang w pliku i tak na to wskazuje,
    -- ale jawne wywołanie jest pewniejsze niezależnie od uprawnień/PATH).
    if exists(build_script) then
        chmodx(build_script)
        sh("lua5.5 " .. quote(build_script))
    else
        io.stderr:write("Błąd: Skrypt " .. build_script .. " nie istnieje!\n")
        os.exit(1)
    end
end

-- =====================================================================
-- GŁÓWNA FUNKCJA
-- =====================================================================

local function main()
    local edition = parse_flag(arg or {})

    io.write("=== Rozpoczynanie przygotowania struktury systemu HackerOS" ..
             (edition and (" (edycja: --" .. edition .. ")") or "") .. " ===\n")

    step_clone_updates_repo()
    step_download_apps()
    step_download_bin_tools(edition)
    step_extract_archives()
    step_copy_desktop_files()
    step_cleanup_updates_repo()

    step_download_vivaldi()

    step_download_hackeros_hacker_tools()
    step_download_steam_bin(edition)
    step_download_games()
    step_hacker_lang()
    step_hnm_skel()
    step_python_venv()
    step_chmod_static_files()

    if edition == "gaming" then
        step_copy_gaming_helpers()
        step_download_gaming_cli_tools()
    end

    local pre_build_fn = edition and EDITION_PRE_BUILD[edition]
    if pre_build_fn then
        pre_build_fn()
    end

    step_run_build(edition)
end

main()
