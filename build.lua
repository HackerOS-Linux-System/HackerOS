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
-- WERSJE APLIKACJI (packages/manifest.hk)
-- =====================================================================

-- Wersje narzędzi/binarek NIE są już zaszyte na sztywno w build.lua -
-- są jedynym źródłem prawdy w packages/manifest.hk, w sekcji [tools],
-- w tym samym formacie co packages.hk/config.hk:
--
--   [tools]
--   -> "Nazwa z odstępami" => vX.Y
--   -> nazwa_bez_odstepow  => vX.Y
--
-- Dzięki temu podbicie wersji dowolnego narzędzia to edycja JEDNEGO
-- pliku (packages/manifest.hk), bez dotykania build.lua.

local MANIFEST_PATH = "packages/manifest.hk"

-- Parsuje sekcję [tools] z packages/manifest.hk do zwykłej tabeli
-- { ["nazwa narzędzia"] = "wersja", ... }. Obsługuje zarówno klucze
-- w cudzysłowie ("Hacker Term"), jak i gołe (hacker, hnm, ...).
local function parse_hk_tools_manifest(path)
    local f = io.open(path, "r")
    if not f then
        io.stderr:write("Błąd: nie znaleziono pliku manifestu wersji: " .. path .. "\n")
        os.exit(1)
    end

    local tools = {}
    local in_tools_section = false

    for line in f:lines() do
        local section = line:match("^%s*%[([%w_%-]+)%]%s*$")
        if section then
            in_tools_section = (section == "tools")
        elseif in_tools_section then
            local qname, qver = line:match('^%s*%-%>%s*"([^"]+)"%s*=>%s*(%S+)%s*$')
            -- UWAGA: klucz gołego (bez cudzysłowu) wpisu to PO PROSTU "cokolwiek
            -- bez spacji" (%S+), NIE tylko [%w_%-]+ jak poprzednio -- realne
            -- nazwy narzędzi w tym ekosystemie zawierają znaki spoza
            -- litery/cyfry/podkreślnika/myślnika (np. "H#"), więc węższa klasa
            -- znaków po cichu GUBIŁA takie wpisy (linia nie pasowała do ŻADNEGO
            -- z dwóch wzorców i była pomijana bez ostrzeżenia -- potem
            -- manifest_version() wywalał się "brak wpisu", mimo że linia W
            -- PLIKU realnie istniała).
            local bname, bver = line:match('^%s*%-%>%s*(%S+)%s*=>%s*(%S+)%s*$')
            local name, ver = qname or bname, qver or bver
            if name and ver then
                tools[name] = ver
            end
        end
    end
    f:close()

    return tools
end

local MANIFEST_TOOLS = parse_hk_tools_manifest(MANIFEST_PATH)

-- Zwraca wersję narzędzia z manifestu albo przerywa build z jasnym
-- komunikatem, jeśli brakuje wpisu (lepiej wywalić się od razu na
-- starcie, niż pobrać/skopiować coś z pustą/nil wersją w środku builda).
local function manifest_version(name)
    local ver = MANIFEST_TOOLS[name]
    if not ver then
        io.stderr:write(
            "Błąd: brak wpisu \"" .. name .. "\" w sekcji [tools] pliku " .. MANIFEST_PATH .. "\n"
        )
        os.exit(1)
    end
    return ver
end

-- Kategoria: HackerOS-Apps
local VER_STORE    = manifest_version("HackerOS Store")
local VER_LAUNCHER = manifest_version("Hacker Launcher")
local VER_PROTON   = manifest_version("Proton Manager")
local VER_TERM     = manifest_version("Hacker Term")
local VER_WELCOME  = manifest_version("HackerOS Welcome")

-- Kategoria: /usr/bin
local VER_CLI    = manifest_version("hacker")
local VER_NIX    = manifest_version("hnm")
local VER_LANG   = manifest_version("Hacker Lang")
local VER_HPM    = manifest_version("hpm")
local VER_CHKER  = manifest_version("chker")
local VER_GETIT  = manifest_version("getit")
local VER_STEAM  = manifest_version("HackerOS Steam")
local VER_HSH    = manifest_version("hsh")
local VER_NGT    = manifest_version("ngt")
local VER_HEDIT  = manifest_version("hedit")

-- Kategoria: HackerOS-Games
local VER_GAMES  = manifest_version("HackerOS Games")

-- Kategoria: gaming-cli (edycja --gaming)
local VER_GAMING = manifest_version("gaming-cli")

-- Kategoria: hammer (edycja --atomic, oraz --container -- patrz
-- step_container_pre_build)
local VER_HAMMER = manifest_version("hammer")

-- UWAGA: WERSJE narzędzi dodatkowych dla --container (Virus, H#,
-- Bytes, HackerOS Builder) CELOWO NIE są odczytywane tutaj jako
-- top-level local (jak VER_HAMMER powyżej) -- gdyby były, manifest_version()
-- przerywałby build.lua przy KAŻDEJ edycji (nawet --atomic, --gaming, bez
-- flagi...), jeśli w packages/manifest.hk zabraknie któregoś z tych
-- wpisów (bo cały plik build.lua jest wykonywany od góry do dołu zanim
-- main() w ogóle spojrzy na flagę --container). Realnie tak się właśnie
-- stało: build --atomic wywalał się błędem "brak wpisu HackerOS-Builder",
-- mimo że --container nawet nie było użyte. Odczyt tych wersji jest więc
-- PRZENIESIONY do step_container_extra_tools() niżej -- wykonuje się
-- wyłącznie gdy faktycznie budujemy --container.

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

-- Nasza własna grafika (marka HackerOS), podmieniana na miejscu domyślnego
-- tła bootloadera live-build (patrz step_apply_boot_splash niżej).
local OUR_SPLASH         = "packages/splash.svg"

-- Katalog, w którym live-build trzyma szablony bootloaderów po
-- zainstalowaniu pakietu (patrz: dpkg -L live-build | grep bootloaders).
local LB_BOOTLOADERS_DIR = "/usr/share/live/build/bootloaders"

-- Główny, wspólny plik źródłowy tła (isolinux/syslinux + grub-pc/grub-efi
-- korzystają z niego podczas konwersji do właściwych formatów przy "lb build").
local SYSTEM_SPLASH      = LB_BOOTLOADERS_DIR .. "/splash.svg"

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
        build_script = "build/build-hackeros-gnome",
        placeholder  = false,
        pre_build    = "gnome",
    },
    xfce = {
        build_script = "build/build-hackeros-xfce",
        placeholder  = false,
        pre_build    = "xfce",
    },
    atomic = {
        build_script = "build/build-hackeros-atomic",
        placeholder  = false,
        pre_build    = "atomic",
    },
    nvidia = {
        build_script = "build/build-hackeros-nvidia",
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
    container = {
        build_script = "build/build-hackeros-container",
        placeholder  = false,
        pre_build    = "container",
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
  --hydra                    Edycja Hydra (helpers/hydra, build/build-hackeros-hydra)
  --lts                      Edycja LTS (helpers/lts, build/build-hackeros-lts)
  --gnome                    Edycja GNOME (helpers/gnome)
  --xfce                     Edycja XFCE (helpers/xfce, build/build-hackeros-xfce)
  --atomic                   Edycja Atomic (Hammer zamiast HackerOS-Store, helpers/atomic,
                              ISO budowane przez hackeros-builder zamiast live-build)
  --nvidia                   Dodatek NVIDIA (helpers/NVIDIA)
  --cybersecurity            Edycja Cybersecurity (branch cybersecurity,
                              build/build-hackeros-cybersecurity)
  --cybersecurity-default    Edycja Cybersecurity Default (branch cybersecurity,
                              build/build-hackeros-cybersecurity-default)
  --container                 Kontener roboczy HackerOS-Builder (helpers/container,
                              build/build-hackeros-container, budowany przez
                              "hackeros-builder build container" zamiast live-build/ISO)
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

    -- Archiwum leży bezpośrednio w etc/skel/oh-my-zsh.tar.gz (NIE w
    -- podkatalogu .config/) i już zawiera w sobie katalog ".oh-my-zsh/"
    -- jako wpis najwyższego poziomu - wystarczy więc rozpakować je od
    -- razu do ETC_SKEL, żeby powstało config/.../etc/skel/.oh-my-zsh/.
    local zsh_archive = ETC_SKEL .. "/oh-my-zsh.tar.gz"
    if exists(zsh_archive) then
        sh("tar -xzf " .. quote(zsh_archive) .. " -C " .. quote(ETC_SKEL))
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

local function step_download_vivaldi(edition)
    if edition == "cybersecurity" or edition == "cybersecurity-default" then
        heading("Tryb --" .. edition .. ": pomijam pobieranie przeglądarki Vivaldi")
        return
    end

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

-- --atomic: instalacja samego Hammer (bez Hammer Store), repo-HackerOS w
-- /etc/hammer, helpers/atomic. HackerOS-Store.desktop ZOSTAJE (klasyczny
-- branding Store) - edycja atomic używa silnika Hammer "pod spodem", ale
-- nie pokazuje osobnej aplikacji/ikony "Hammer Store".
local function step_atomic_pre_build()
    heading("Tryb --atomic: dodatkowe operacje")

    -- Binarka hammer (BEZ hammer-store - edycja atomic nie ma osobnej
    -- aplikacji Hammer Store, tylko klasyczny HackerOS-Store).
    mkdirp(TARGET_BIN)
    do
        local name = "hammer"
        local url  = "https://github.com/HackerOS-Linux-System/hammer/releases/download/" ..
                     VER_HAMMER .. "/" .. name
        local dest = TARGET_BIN .. "/" .. name
        download(url, dest)
        chmodx(dest)
    end

    -- repo-HackerOS z klonu hammer -> /etc/hammer
    step_atomic_hammer_repo()

    -- helpers/atomic -> config/
    copy_helper_dir("helpers/atomic", false)
end

-- =====================================================================
-- --container: KONTENER ROBOCZY HackerOS-Builder
-- =====================================================================
-- W odróżnieniu od --atomic (obraz OCI atomowy + ISO instalacyjne),
-- --container przygotowuje strukturę config/ dla "hackeros-builder build
-- container" -- zwykły kontener roboczy (podman/docker), bez hammer, bez
-- ISO, bez usuwania apt/apt-get z rootfs (patrz ProjectTypeContainer w
-- repo HackerOS-Builder, internal/config/config.go). main() już wykonuje
-- dla TEJ edycji dokładnie te same kroki bazowe co dla official (klon
-- HackerOS-Updates, HackerOS-Apps, narzędzia /usr/bin, gry, Hacker-Lang,
-- venv Pythona, ...) -- ta funkcja dokłada WYŁĄCZNIE to, co jest
-- specyficzne dla kontenera.

-- Ścieżka pliku źródłowego z listą pakietów kontenera -- ZWYKŁY, płaski
-- plik (jedna nazwa pakietu na linię, komentarze "#" dozwolone), NIE w
-- formacie *.list.chroot. Dostarczany osobno (poza tym repo w chwili
-- pisania tego kodu) -- patrz KROK "lista pakietów" niżej, który go
-- konwertuje do formatu jakiego oczekuje hackeros-builder.
local CONTAINER_PACKAGE_LIST_SRC = "helpers/container/package-list"
local PACKAGE_LISTS_DIR          = "config/package-lists"
local CONTAINER_PACKAGE_LIST_DST = PACKAGE_LISTS_DIR .. "/99-container.list.chroot"

-- Usuwa config/package-lists/live.list.chroot ORAZ cały katalog
-- includes.chroot_after_packages/etc/calamares.
--
-- Dlaczego CAŁY live.list.chroot, nie tylko wpisy calamares (jak robi to
-- build/build-hackeros-atomic dla edycji --atomic): live.list.chroot to
-- lista pakietów PEŁNEGO środowiska graficznego (plasma-desktop, sddm,
-- dolphin, kate, ...) przygotowana pod live-build/atomic -- kompletnie
-- nieodpowiednia dla zwykłego, headless kontenera roboczego. Jedynym
-- źródłem prawdy o pakietach kontenera ma być
-- CONTAINER_PACKAGE_LIST_DST (skopiowany z helpers/container/package-list
-- w step_container_package_list) -- hackeros-builder scala WSZYSTKIE
-- pliki *.list.chroot w config/package-lists/ bezwarunkowo (patrz
-- internal/liveparse/project.go w repo hackeros-builder), więc
-- live.list.chroot musi zniknąć z tego katalogu PRZED wywołaniem
-- hackeros-buildera, inaczej te ~50 pakietów środowiska graficznego
-- trafiłoby do kontenera obok właściwej listy.
--
-- Usunięcie samego pliku (repo jest i tak świeżym checkoutem w CI, więc
-- nic globalnie nie psuje) jest prostsze i solidniejsze niż filtrowanie
-- linii, i przy okazji całkowicie eliminuje potrzebę osobnego wykluczania
-- "calamares"/"calamares-settings-debian" z tej listy -- nie ma jej już
-- wcale.
--
-- Katalog includes.chroot_after_packages/etc/calamares usuwamy mimo to,
-- jako dodatkowe zabezpieczenie (np. gdyby package-list kontenera
-- kiedyś przypadkiem dodał "calamares") -- ten katalog JEST kopiowany do
-- rootfs kontenera w całości przez hackeros-builder (krok "copy
-- includes.chroot_after_packages" w internal/rootfs/builder.go, ten sam
-- mechanizm dla KAŻDEGO build targetu -- cloud/iso/container), więc
-- usunięcie etc/calamares TUTAJ, PRZED wywołaniem hackeros-buildera, jest
-- równoznaczne z "skopiuj etc/ do /etc poza katalogiem calamares".
local function remove_desktop_packages_and_calamares_for_container()
    local liveListPath = PACKAGE_LISTS_DIR .. "/live.list.chroot"
    if exists(liveListPath) then
        sh("rm -f " .. quote(liveListPath))
        io.write("Usunięto (tylko dla --container): " .. liveListPath .. "\n")
    end

    local calamaresConfigDir = "config/includes.chroot_after_packages/etc/calamares"
    if exists(calamaresConfigDir) then
        sh("rm -rf " .. quote(calamaresConfigDir))
        io.write("Usunięto katalog: " .. calamaresConfigDir .. "\n")
    end
end

-- Konwertuje CONTAINER_PACKAGE_LIST_SRC (płaski plik) na
-- CONTAINER_PACKAGE_LIST_DST (*.list.chroot) -- hackeros-builder scala
-- WSZYSTKIE pliki *.list.chroot w config/package-lists/ (patrz
-- internal/liveparse/project.go w repo hackeros-builder), więc wystarczy
-- skopiować zawartość pod nazwą kończącą się na ".list.chroot"; nie trzeba
-- nic parsować ani scalać ręcznie w Lua.
local function step_container_package_list()
    heading("Konwersja " .. CONTAINER_PACKAGE_LIST_SRC .. " -> " .. CONTAINER_PACKAGE_LIST_DST)

    if not exists(CONTAINER_PACKAGE_LIST_SRC) then
        io.stderr:write(
            "Błąd: nie znaleziono " .. CONTAINER_PACKAGE_LIST_SRC .. " -- edycja --container " ..
            "wymaga tego pliku (lista pakietów apt do zainstalowania w kontenerze, " ..
            "jedna nazwa na linię, linie zaczynające się od '#' są ignorowane).\n"
        )
        os.exit(1)
    end

    mkdirp(PACKAGE_LISTS_DIR)
    sh("cp " .. quote(CONTAINER_PACKAGE_LIST_SRC) .. " " .. quote(CONTAINER_PACKAGE_LIST_DST))
end

-- Pobiera do TARGET_BIN (config/includes.chroot_after_packages/usr/bin)
-- binarki DODATKOWE, instalowane WYŁĄCZNIE w kontenerze -- NIE trafiają do
-- żadnej innej edycji. Ten katalog jest kopiowany przez hackeros-builder
-- 1:1 do rootfs/usr/ (patrz komentarz przy remove_calamares_from_config
-- wyżej) -- stąd "kopiowanie do /usr/" opisane w wymaganiach dzieje się
-- automatycznie, bez dodatkowego kodu tutaj.
local function step_container_extra_tools()
    heading("Tryb --container: pobieranie dodatkowych narzędzi deweloperskich do /usr/bin")

    mkdirp(TARGET_BIN)

    -- { nazwa binarki, organizacja/repo GitHub, wersja }
    -- UWAGA: Bytes żyje pod ORGANIZACJĄ "Bytes-Repository", NIE
    -- "HackerOS-Linux-System" jak reszta -- dlatego pełna ścieżka
    -- org/repo jest podawana jawnie dla każdego narzędzia zamiast
    -- zakładać wspólny prefiks (tak jak robią to inne pętle w tym pliku).
    --
    -- Wersje odczytywane TUTAJ (dopiero w momencie wywołania tej funkcji,
    -- NIE jako top-level local na górze pliku) -- patrz komentarz przy
    -- VER_HAMMER. Klucze DOKŁADNIE takie, jak w packages/manifest.hk
    -- (uwaga: "HackerOS Builder" ma SPACJĘ, nie myślnik).
    local extra_tools = {
        { name = "virus",            org_repo = "HackerOS-Linux-System/Virus",             ver = manifest_version("Virus") },
        { name = "hsharp",           org_repo = "HackerOS-Linux-System/H-Sharp",           ver = manifest_version("H#") },
        { name = "bytes",            org_repo = "Bytes-Repository/bytes",                  ver = manifest_version("Bytes") },
        { name = "hackeros-builder", org_repo = "HackerOS-Linux-System/HackerOS-Builder",  ver = manifest_version("HackerOS Builder") },
        -- hammer jest też pobierany dla --atomic (step_atomic_pre_build),
        -- ale to ODDZIELNE wywołanie/miejsce w drzewie -- kontener ma
        -- dostać własną kopię w TYM SAMYM miejscu co pozostałe narzędzia.
        { name = "hammer",           org_repo = "HackerOS-Linux-System/hammer",            ver = VER_HAMMER },
    }

    for _, tool in ipairs(extra_tools) do
        local url  = "https://github.com/" .. tool.org_repo ..
                     "/releases/download/" .. tool.ver .. "/" .. tool.name
        local dest = TARGET_BIN .. "/" .. tool.name
        download(url, dest)
        chmodx(dest)
    end
end

-- --container: lista pakietów, usunięcie Calamares, dodatkowe binarki,
-- helpers/container -> config/. Wszystkie inne narzędzia (HackerOS-Apps,
-- /usr/bin, gry, Hacker-Lang, venv Pythona, ...) są już pobrane przez
-- main() PRZED wywołaniem tej funkcji -- dokładnie te same kroki co dla
-- official, więc nie są tu powtarzane.
local function step_container_pre_build()
    heading("Tryb --container: dodatkowe operacje")

    step_container_package_list()
    remove_desktop_packages_and_calamares_for_container()
    step_container_extra_tools()

    -- helpers/container -> config/ (np. config.hk z [project] -> type =>
    -- container; patrz plik dostarczony razem z tą zmianą). Analogicznie
    -- do copy_helper_dir("helpers/atomic", false).
    copy_helper_dir("helpers/container", false)
end

-- Tabela dowiązująca klucz pre_build z EDITIONS do konkretnej funkcji.
local EDITION_PRE_BUILD = {
    hydra     = step_hydra_pre_build,
    lts       = step_lts_pre_build,
    gnome     = step_gnome_pre_build,
    xfce      = step_xfce_pre_build,
    nvidia    = step_nvidia_pre_build,
    atomic    = step_atomic_pre_build,
    container = step_container_pre_build,
}

-- =====================================================================
-- KROK 16.5: PODMIANA TŁA BOOTLOADERA (splash.svg) NA GRAFIKĘ HackerOS
-- =====================================================================

-- Podmienia domyślny plik splash.svg zaszyty w plikach systemowych
-- pakietu live-build (/usr/share/live/build/bootloaders/splash.svg) na
-- własną grafikę HackerOS (packages/splash.svg).
--
-- Skąd bierze się domyślne tło: pakiet live-build trzyma jeden wspólny
-- plik źródłowy splash.svg, z którego w trakcie etapu "lb binary" są
-- generowane tła w odpowiednich formatach/rozdzielczościach osobno dla
-- każdego bootloadera (isolinux/syslinux oraz grub-pc/grub-efi). Dzięki
-- temu wystarczy podmienić ten JEDEN plik źródłowy .svg - nie trzeba nic
-- ręcznie przeliczać ani przerabiać na PNG/LSS w konkretnych rozdzielczościach.
--
-- Co ZOSTAJE bez zmian: wpisy tekstowe menu ("Live (amd64)" / "Live
-- (amd64 failsafe)" / "Utilities"), obsługa klawiszy ENTER/TAB itd. - to
-- wszystko żyje w osobnych plikach szablonów (menu.cfg / stdmenu.cfg /
-- live.cfg.in) i nie jest tu ruszane. Zmienia się WYŁĄCZNIE grafika tła.
--
-- Musi się wykonać PO instalacji live-build (patrz krok "Instalacja
-- live-build" w workflow CI), ale PRZED uruchomieniem właściwego builda
-- (step_run_build), bo to on odpala "lb build", które faktycznie
-- konwertuje splash.svg na tła dla poszczególnych bootloaderów.
local function step_apply_boot_splash()
    heading("Podmiana tła bootloadera (splash.svg) na grafikę HackerOS")

    if not exists(OUR_SPLASH) then
        io.stderr:write(
            "Błąd: nie znaleziono " .. OUR_SPLASH .. " w repozytorium - " ..
            "pomijam podmianę tła bootloadera.\n"
        )
        os.exit(1)
    end

    if not isdir(LB_BOOTLOADERS_DIR) then
        io.write(
            "Ostrzeżenie: katalog " .. LB_BOOTLOADERS_DIR .. " nie istnieje " ..
            "(live-build nie jest jeszcze zainstalowany na tym etapie?) - " ..
            "pomijam podmianę tła bootloadera.\n"
        )
        return
    end

    -- Główny plik używany przez live-build do generowania teł dla
    -- isolinux/syslinux oraz grub-pc/grub-efi.
    if exists(SYSTEM_SPLASH) then
        sh("sudo cp -f " .. quote(OUR_SPLASH) .. " " .. quote(SYSTEM_SPLASH))
        io.write("Podmieniono " .. SYSTEM_SPLASH .. " na " .. OUR_SPLASH .. "\n")
    else
        io.write(
            "Ostrzeżenie: nie znaleziono " .. SYSTEM_SPLASH ..
            " w tej wersji live-build - sprawdzam dodatkowe lokalizacje.\n"
        )
    end

    -- Zabezpieczenie na wypadek innej wersji live-build, która trzyma
    -- dodatkowe/osobne pliki tła per-bootloader (np. w podkatalogach
    -- grub-pc/, grub-efi/, isolinux/, syslinux/, syslinux_common/).
    --
    -- Pliki *.svg podmieniamy 1:1 (to zwykła grafika wektorowa - taka
    -- sama jak nasza). Pliki *.png NIE są nadpisywane surową zawartością
    -- SVG (to zepsułoby plik) - próbujemy je realnie przekonwertować
    -- narzędziem rsvg-convert/convert, jeśli jest dostępne; jeśli nie,
    -- tylko ostrzegamy i zostawiamy oryginał bez zmian.
    local find_svg_cmd =
        "find " .. quote(LB_BOOTLOADERS_DIR) ..
        " -mindepth 2 -type f -name 'splash.svg' 2>/dev/null"

    local svg_handle = io.popen(find_svg_cmd)
    if svg_handle then
        for path in svg_handle:lines() do
            io.write("Znaleziono dodatkowy plik tła bootloadera (svg): " .. path .. " - podmieniam\n")
            sh("sudo cp -f " .. quote(OUR_SPLASH) .. " " .. quote(path))
        end
        svg_handle:close()
    end

    local find_png_cmd =
        "find " .. quote(LB_BOOTLOADERS_DIR) ..
        " -mindepth 2 -type f -name 'splash.png' 2>/dev/null"

    local png_handle = io.popen(find_png_cmd)
    if png_handle then
        for path in png_handle:lines() do
            io.write("Znaleziono dodatkowy plik tła bootloadera (png): " .. path .. "\n")
            if os.execute("command -v rsvg-convert >/dev/null 2>&1") == true then
                sh("rsvg-convert " .. quote(OUR_SPLASH) .. " -o /tmp/hackeros-splash.png", true)
                sh("sudo cp -f /tmp/hackeros-splash.png " .. quote(path), true)
            elseif os.execute("command -v convert >/dev/null 2>&1") == true then
                sh("convert " .. quote(OUR_SPLASH) .. " /tmp/hackeros-splash.png", true)
                sh("sudo cp -f /tmp/hackeros-splash.png " .. quote(path), true)
            else
                io.write(
                    "Ostrzeżenie: brak rsvg-convert/convert - nie mogę " ..
                    "przekonwertować " .. OUR_SPLASH .. " do PNG, pomijam " .. path .. "\n"
                )
            end
        end
        png_handle:close()
    end

    io.write("Podmiana tła bootloadera zakończona.\n")
end

-- =====================================================================
-- KROK 17: URUCHOMIENIE SKRYPTU BUDUJĄCEGO SYSTEM
-- =====================================================================

-- Wybiera skrypt budujący zależnie od edycji: dla edycji w pełni
-- obsługiwanych (np. gaming, blue, hydra, lts, xfce) używa
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

    step_download_vivaldi(edition)

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

    step_apply_boot_splash()
    step_run_build(edition)
end

main()
