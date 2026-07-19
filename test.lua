#!/usr/bin/env lua

local REPO          = "HackerOS-Linux-System/HackerOS"
local ARTIFACT_HINT = "hackeros%-v4%.9%-official" -- dopasowanie (lowercase, lua pattern)
local API_BASE       = "https://api.github.com/repos/" .. REPO
local WORKDIR         = (os.getenv("HOME") or "/tmp") .. "/.cache/hackeros-test"
local TOKEN            = os.getenv("GITHUB_TOKEN")

math.randomseed(os.time())

---------------------------------------------------------------------
-- Pomocnicze funkcje
---------------------------------------------------------------------

local function exec_capture(cmd)
    local h = io.popen(cmd .. " 2>&1")
    if not h then return "", false end
    local out = h:read("*a") or ""
    local ok = h:close()
    return out, ok and true or false
end

local function run(cmd)
    -- Uruchamia polecenie "na żywo" (np. QEMU), zwraca kod wyjścia
    local ok, how, code = os.execute(cmd)
    if type(ok) == "number" then return ok == 0 end -- lua 5.1 kompatybilność
    return ok == true
end

local function has_cmd(cmd)
    local out = exec_capture("command -v " .. cmd)
    return out:match("%S") ~= nil
end

local function ask(prompt)
    io.write(prompt)
    io.flush()
    local line = io.read("*l")
    return line or ""
end

local function ask_yes_no(prompt, default_no)
    local ans = ask(prompt .. (default_no and " [t/N]: " or " [T/n]: "))
    ans = ans:lower()
    if default_no then
        return ans == "t" or ans == "tak" or ans == "y" or ans == "yes"
    else
        return not (ans == "n" or ans == "nie" or ans == "no")
    end
end

local function info(msg)  print("[INFO]  " .. msg) end
local function warn(msg)  print("[UWAGA] " .. msg) end
local function die(msg)
    io.stderr:write("[BŁĄD]  " .. msg .. "\n")
    os.exit(1)
end

local function mkdirp(path)
    exec_capture("mkdir -p " .. string.format("%q", path))
end

---------------------------------------------------------------------
-- Sprawdzenie zależności
---------------------------------------------------------------------

local function check_dependencies()
    local required = { "curl", "jq", "unzip", "tar", "find" }
    local missing = {}
    for _, c in ipairs(required) do
        if not has_cmd(c) then table.insert(missing, c) end
    end
    if #missing > 0 then
        die("Brakuje wymaganych narzędzi: " .. table.concat(missing, ", ") ..
            ". Zainstaluj je i uruchom skrypt ponownie.")
    end
end

---------------------------------------------------------------------
-- Zapytania do GitHub API
---------------------------------------------------------------------

local function curl_headers()
    local h = '-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28"'
    if TOKEN then
        h = h .. ' -H "Authorization: Bearer ' .. TOKEN .. '"'
    end
    return h
end

-- Wykonuje żądanie GET do GitHub API. Jeśli odpowiedź wskazuje, że
-- potrzebny jest token (przekroczony limit zapytań, brak autoryzacji,
-- wymagane uwierzytelnienie) a token nie jest jeszcze ustawiony,
-- PYTA UŻYTKOWNIKA O TOKEN W TRAKCIE DZIAŁANIA i automatycznie ponawia
-- żądanie. Zwraca treść odpowiedzi (JSON jako string).
local function api_get(url)
    local function do_request()
        local cmd = string.format('curl -s -w "\\n%%{http_code}" %s "%s"', curl_headers(), url)
        local out = exec_capture(cmd)
        local body, code = out:match("^(.*)\n(%d+)%s*$")
        if not body then body, code = out, "" end
        return body, code
    end

    local body, code = do_request()

    local needs_auth = (code == "401" or code == "403")
        or body:find('"message"%s*:%s*"[^"]-[Rr]ate limit[^"]*"') ~= nil
        or body:find('"message"%s*:%s*"[Bb]ad credentials"') ~= nil
        or body:find('"message"%s*:%s*"[Rr]equires authentication"') ~= nil
        or body:find('"message"%s*:%s*"[^"]-API rate limit exceeded[^"]*"') ~= nil

    if needs_auth and not TOKEN then
        warn("GitHub API zgłosił potrzebę uwierzytelnienia (limit zapytań lub brak dostępu).")
        local t = ask("Podaj token GitHub (Personal Access Token), aby kontynuować: ")
        if t == "" then
            die("Bez tokenu nie można kontynuować - GitHub API odrzuca żądania.")
        end
        TOKEN = t
        info("Ponawiam żądanie z podanym tokenem...")
        body, code = do_request()
        if code == "401" or code == "403" then
            die("Podany token nie działa (GitHub zwrócił błąd autoryzacji). Sprawdź jego uprawnienia i spróbuj ponownie.")
        end
    end

    return body
end

-- Znajduje ID najnowszego zakończonego sukcesem workflow run
local function get_latest_successful_run_id()
    info("Pobieranie listy ostatnich uruchomień workflow...")
    local out = api_get(API_BASE .. "/actions/runs?per_page=20")
    local jq_cmd = "echo " .. string.format("%q", out) ..
        " | jq -r '.workflow_runs | map(select(.status==\"completed\" and .conclusion==\"success\")) | .[0].id // empty'"
    local id = exec_capture(jq_cmd):gsub("%s+$", "")
    if id == "" then
        die("Nie znaleziono żadnego zakończonego sukcesem uruchomienia workflow w " .. REPO)
    end
    return id
end

-- Pobiera listę artefaktów dla danego run_id, zwraca tabelę
-- { {id=, name=, size=, url=}, ... }
local function get_artifacts(run_id)
    info("Pobieranie listy artefaktów dla uruchomienia #" .. run_id .. "...")
    local out = api_get(API_BASE .. "/actions/runs/" .. run_id .. "/artifacts?per_page=100")
    local jq_cmd = "echo " .. string.format("%q", out) ..
        [[ | jq -r '.artifacts[] | "\(.id)\t\(.name)\t\(.size_in_bytes)\t\(.archive_download_url)"']]
    local lines = exec_capture(jq_cmd)

    local artifacts = {}
    for line in lines:gmatch("[^\r\n]+") do
        local id, name, size, url = line:match("^(%d+)\t(.-)\t(%d+)\t(.+)$")
        if id then
            table.insert(artifacts, { id = id, name = name, size = tonumber(size), url = url })
        end
    end
    return artifacts
end

local function filter_matching(artifacts)
    local matches = {}
    for _, a in ipairs(artifacts) do
        if a.name:lower():find(ARTIFACT_HINT) then
            table.insert(matches, a)
        end
    end
    return matches
end

local function human_size(bytes)
    local units = { "B", "KB", "MB", "GB" }
    local i = 1
    local val = bytes
    while val > 1024 and i < #units do
        val = val / 1024
        i = i + 1
    end
    return string.format("%.2f %s", val, units[i])
end

local function choose_artifact(matches)
    if #matches == 0 then
        die('Nie znaleziono żadnego artefaktu pasującego do "HackerOS-V4.9-official" w najnowszym uruchomieniu.')
    elseif #matches == 1 then
        info("Znaleziono jeden pasujący artefakt: " .. matches[1].name)
        return matches[1]
    end

    print("\nZnaleziono kilka pasujących artefaktów:")
    for i, a in ipairs(matches) do
        print(string.format("  [%d] %s (%s)", i, a.name, human_size(a.size)))
    end

    local choice
    repeat
        local ans = ask("\nKtóry pobrać? Podaj numer: ")
        choice = tonumber(ans)
    until choice and matches[choice]

    return matches[choice]
end

---------------------------------------------------------------------
-- Pobieranie
---------------------------------------------------------------------

-- Generuje unikalną nazwę kontenera dla danego etapu (download/qemu)
local function new_container_name(prefix)
    return prefix .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
end

-- Usuwa (jeśli istnieje) kontener podman o podanej nazwie
local function remove_container(name)
    info("Usuwam kontener podman: " .. name)
    exec_capture('podman rm -f "' .. name .. '" >/dev/null 2>&1')
end

-- Buduje fragment nagłówka autoryzacji dla curl/aria2c - pomijany,
-- jeśli TOKEN nie jest (jeszcze) ustawiony.
local function bearer_curl_header()
    if TOKEN then return '-H "Authorization: Bearer ' .. TOKEN .. '"' end
    return ""
end

local function bearer_aria2_header()
    if TOKEN then return '--header="Authorization: Bearer ' .. TOKEN .. '"' end
    return ""
end

-- Pobieranie za pomocą aria2c uruchomionego wewnątrz kontenera podman
-- (używane gdy aria2c nie jest zainstalowany lokalnie, a użytkownik
-- zgodził się na pobieranie w kontenerze). Kontener jest usuwany zaraz
-- po zakończeniu pobierania. Zwraca true/false (nie przerywa programu).
local function download_via_container_aria2c(artifact, zip_name)
    local container_name = new_container_name("hackeros-dl")
    info("Pobieranie w kontenerze podman (aria2c)...")

    local inner_cmd = string.format(
        'apk add --no-cache aria2 >/dev/null 2>&1 || ' ..
        '(apt-get update -qq && apt-get install -y -qq aria2 >/dev/null 2>&1) || ' ..
        '(dnf install -y -q aria2 >/dev/null 2>&1); ' ..
        'aria2c -x16 -s16 -k1M %s --header="Accept: application/vnd.github+json" ' ..
        '-d /work -o "%s" "%s"',
        bearer_aria2_header(), zip_name, artifact.url
    )

    local cmd = string.format(
        'podman run --name %s -v "%s":/work:Z docker.io/library/alpine:latest sh -c %s',
        container_name, WORKDIR, string.format("%q", inner_cmd)
    )

    local ok = run(cmd)
    remove_container(container_name)
    return ok
end

-- Sprawdza, czy plik jest poprawnym, niepustym archiwum zip
local function is_valid_zip(path)
    local out = exec_capture(string.format('test -s "%s" && unzip -tq "%s" >/dev/null 2>&1 && echo VALID', path, path))
    return out:find("VALID") ~= nil
end

-- Pobiera artefakt. Skrypt NIE wymaga tokenu z góry - próbuje pobrać
-- bez niego, a dopiero gdy wykryje, że pobieranie się nie powiodło
-- (co GitHub sygnalizuje właśnie wtedy, gdy token jest wymagany),
-- PYTA O TOKEN W TRAKCIE DZIAŁANIA i automatycznie ponawia próbę.
local function download_artifact(artifact)
    mkdirp(WORKDIR)
    local zip_name = artifact.id .. ".zip"
    local zip_path = WORKDIR .. "/" .. zip_name

    info("Pobieranie artefaktu: " .. artifact.name .. " (" .. human_size(artifact.size) .. ")")

    -- Metodę pobierania wybieramy raz, niezależnie od tego, czy token
    -- będzie potrzebny.
    local method = "curl"
    if has_cmd("aria2c") then
        method = "aria2c_local"
        info("Używam lokalnego aria2c (pobieranie wieloczęściowe, szybsze).")
    else
        warn("aria2c nie jest zainstalowany lokalnie.")
        local use_container = ask_yes_no(
            "Czy pobrać w kontenerze podman z zainstalowanym aria2c (szybciej niż curl)?",
            true
        )
        if use_container and has_cmd("podman") then
            method = "aria2c_container"
        elseif use_container then
            warn("Nie znaleziono podman - przechodzę na curl lokalnie.")
        end
    end

    local function attempt()
        os.remove(zip_path) -- usuń pozostałości po ewentualnej nieudanej próbie

        if method == "aria2c_local" then
            local cmd = string.format(
                'aria2c -x16 -s16 -k1M %s --header="Accept: application/vnd.github+json" ' ..
                '-o "%s" -d "%s" "%s"',
                bearer_aria2_header(), zip_name, WORKDIR, artifact.url
            )
            return run(cmd)
        elseif method == "aria2c_container" then
            return download_via_container_aria2c(artifact, zip_name)
        else
            local cmd = string.format(
                'curl -sL %s -H "Accept: application/vnd.github+json" -o "%s" "%s"',
                bearer_curl_header(), zip_path, artifact.url
            )
            return run(cmd)
        end
    end

    attempt()

    if not is_valid_zip(zip_path) and not TOKEN then
        warn("Pobrany plik jest nieprawidłowy - GitHub wymaga tokenu do pobrania artefaktów Actions.")
        local t = ask("Podaj token GitHub (Personal Access Token z uprawnieniem 'actions:read'): ")
        if t == "" then
            die("Bez tokenu nie można pobrać artefaktu.")
        end
        TOKEN = t
        info("Ponawiam pobieranie z podanym tokenem...")
        attempt()
    end

    if not is_valid_zip(zip_path) then
        die("Pobieranie nie powiodło się - sprawdź token, uprawnienia i połączenie sieciowe.")
    end

    info("Pobieranie zakończone: " .. zip_path)
    return zip_path
end

---------------------------------------------------------------------
-- Rozpakowywanie (rekurencyjne, aż do znalezienia .iso)
---------------------------------------------------------------------

local function extract_archive(path, dest)
    mkdirp(dest)
    local lower = path:lower()
    local cmd
    if lower:match("%.zip$") then
        cmd = string.format('unzip -o -q "%s" -d "%s"', path, dest)
    elseif lower:match("%.tar%.gz$") or lower:match("%.tgz$") then
        cmd = string.format('tar -xzf "%s" -C "%s"', path, dest)
    elseif lower:match("%.tar%.xz$") or lower:match("%.txz$") then
        cmd = string.format('tar -xJf "%s" -C "%s"', path, dest)
    elseif lower:match("%.tar%.bz2$") then
        cmd = string.format('tar -xjf "%s" -C "%s"', path, dest)
    elseif lower:match("%.tar$") then
        cmd = string.format('tar -xf "%s" -C "%s"', path, dest)
    elseif lower:match("%.gz$") then
        cmd = string.format('gzip -dk "%s" -c > "%s/%s"', path, dest, path:match("([^/]+)%.gz$"))
    elseif lower:match("%.xz$") then
        cmd = string.format('xz -dk "%s" -c > "%s/%s"', path, dest, path:match("([^/]+)%.xz$"))
    elseif lower:match("%.7z$") then
        if not has_cmd("7z") then
            die("Znaleziono archiwum .7z, ale narzędzie 7z nie jest zainstalowane.")
        end
        cmd = string.format('7z x -o"%s" -y "%s" >/dev/null', dest, path)
    else
        return nil -- nie jest archiwum obsługiwanym przez tę funkcję
    end
    local ok = run(cmd)
    if not ok then die("Rozpakowywanie nie powiodło się: " .. path) end
    return dest
end

local function find_files(dir, pattern)
    local out = exec_capture(string.format('find "%s" -type f -iname "%s"', dir, pattern))
    local files = {}
    for line in out:gmatch("[^\r\n]+") do
        table.insert(files, line)
    end
    return files
end

-- Rozpakowuje wielopoziomowo, aż znajdzie plik(i) .iso, zwraca listę ścieżek do ISO
local function unpack_until_iso(zip_path)
    local extract_dir = WORKDIR .. "/extracted"
    mkdirp(extract_dir)

    info("Rozpakowywanie artefaktu...")
    extract_archive(zip_path, extract_dir)

    -- Pętla: dopóki nie ma iso, próbuj rozpakować kolejne znalezione archiwa
    for _ = 1, 5 do -- maks. 5 poziomów zagnieżdżenia, zabezpieczenie przed pętlą
        local isos = find_files(extract_dir, "*.iso")
        if #isos > 0 then return isos end

        local archive_exts = { "*.zip", "*.tar.gz", "*.tgz", "*.tar.xz", "*.txz",
                                "*.tar.bz2", "*.tar", "*.gz", "*.xz", "*.7z" }
        local found_any = false
        for _, ext in ipairs(archive_exts) do
            for _, f in ipairs(find_files(extract_dir, ext)) do
                found_any = true
                info("Znaleziono zagnieżdżone archiwum: " .. f .. " - rozpakowuję...")
                extract_archive(f, extract_dir)
            end
        end
        if not found_any then break end
    end

    local isos = find_files(extract_dir, "*.iso")
    if #isos == 0 then
        die("Nie znaleziono pliku .iso po rozpakowaniu artefaktu.")
    end
    return isos
end

local function choose_iso(isos)
    if #isos == 1 then return isos[1] end
    print("\nZnaleziono kilka plików ISO:")
    for i, f in ipairs(isos) do
        print(string.format("  [%d] %s", i, f))
    end
    local choice
    repeat
        local ans = ask("\nKtóry uruchomić? Podaj numer: ")
        choice = tonumber(ans)
    until choice and isos[choice]
    return isos[choice]
end

---------------------------------------------------------------------
-- Uruchamianie QEMU
---------------------------------------------------------------------

local function run_qemu_locally(iso_path)
    info("Uruchamiam QEMU lokalnie: " .. iso_path)
    local kvm_flag = ""
    if exec_capture("test -e /dev/kvm && echo ok"):find("ok") then
        kvm_flag = "-enable-kvm"
    else
        warn("Brak /dev/kvm - emulacja będzie wolniejsza (bez akceleracji sprzętowej).")
    end
    local cmd = string.format(
        'qemu-system-x86_64 -m 4096 %s -cdrom "%s" -boot d -vga virtio -display gtk',
        kvm_flag, iso_path
    )
    return run(cmd)
end

-- Uruchamia QEMU wewnątrz kontenera podman (jedyne wspierane narzędzie
-- kontenerowe - świadomie NIE używamy docker). Kontener otrzymuje nazwę
-- i jest jawnie usuwany zaraz po zakończeniu działania QEMU.
local function run_qemu_in_container(iso_path)
    if not has_cmd("podman") then
        die("Nie znaleziono podman - nie mogę utworzyć kontenera z QEMU (obsługiwany jest wyłącznie podman).")
    end

    local container_name = new_container_name("hackeros-qemu")
    info("Tworzę kontener podman '" .. container_name .. "' z QEMU...")

    local iso_dir  = iso_path:match("^(.*)/[^/]+$")
    local iso_name = iso_path:match("[^/]+$")

    local kvm_mount = ""
    if exec_capture("test -e /dev/kvm && echo ok"):find("ok") then
        kvm_mount = "--device /dev/kvm"
    else
        warn("Brak /dev/kvm na hoście - w kontenerze QEMU zadziała bez akceleracji sprzętowej.")
    end

    local inner_cmd =
        "dnf install -y qemu-kvm >/dev/null 2>&1 || " ..
        "(apt-get update -qq && apt-get install -y -qq qemu-system-x86 >/dev/null 2>&1); " ..
        "qemu-system-x86_64 -m 4096 -cdrom /iso/" .. iso_name .. " -boot d -display gtk"

    local cmd = string.format(
        'podman run --name %s -it %s -v "%s":/iso:Z docker.io/library/fedora:latest bash -c %s',
        container_name, kvm_mount, iso_dir, string.format("%q", inner_cmd)
    )

    local ok = run(cmd)

    -- Kontener usuwany jawnie po zakończeniu pracy QEMU (niezależnie od wyniku)
    remove_container(container_name)

    return ok
end

local function launch_iso(iso_path)
    if has_cmd("qemu-system-x86_64") then
        return run_qemu_locally(iso_path)
    end

    warn("QEMU (qemu-system-x86_64) nie jest zainstalowane w systemie.")
    local wants_auto = ask_yes_no(
        "Czy mam automatycznie utworzyć kontener, zainstalować w nim QEMU i uruchomić obraz?",
        true
    )
    if not wants_auto then
        die("Zainstaluj QEMU ręcznie (np. 'sudo pacman -S qemu-full' lub 'sudo apt install qemu-system-x86') i uruchom skrypt ponownie.")
    end

    return run_qemu_in_container(iso_path)
end

---------------------------------------------------------------------
-- Sprzątanie
---------------------------------------------------------------------

local function cleanup(iso_path, zip_path)
    info("Sprzątanie plików tymczasowych...")
    if iso_path then
        os.remove(iso_path)
    end
    if zip_path then
        os.remove(zip_path)
    end
    exec_capture(string.format('rm -rf "%s/extracted"', WORKDIR))
    info("Gotowe. Usunięto pobrany obraz ISO i pliki tymczasowe.")
end

---------------------------------------------------------------------
-- Główny przebieg programu
---------------------------------------------------------------------

local function main()
    check_dependencies()
    mkdirp(WORKDIR)

    local run_id       = get_latest_successful_run_id()
    local artifacts     = get_artifacts(run_id)
    local matches        = filter_matching(artifacts)
    local artifact         = choose_artifact(matches)

    local zip_path = download_artifact(artifact)
    local isos      = unpack_until_iso(zip_path)
    local iso_path   = choose_iso(isos)

    print("")
    info("Uruchamianie obrazu: " .. iso_path)
    local ok = launch_iso(iso_path)
    if not ok then
        warn("QEMU zakończyło pracę z błędem (lub zostało przerwane).")
    end

    cleanup(iso_path, zip_path)
end

main()
