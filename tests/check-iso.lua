#!/usr/bin/env lua

-- Kolory ANSI do formatowania wyjścia
local colors = {
    reset   = "\27[0m",
    red     = "\27[0;31m",
    green   = "\27[0;32m",
    yellow  = "\27[1;33m",
    blue    = "\27[0;34m"
}

local function log_info(msg)    print(colors.blue .. "[INFO] " .. colors.reset .. msg) end
local function log_ok(msg)      print(colors.green .. "[OK] " .. colors.reset .. msg) end
local function log_warn(msg)    print(colors.yellow .. "[OSTRZEŻENIE] " .. colors.reset .. msg) end
local function log_error(msg)   print(colors.red .. "[BŁĄD] " .. colors.reset .. msg) end

-- Funkcja pomocnicza do sprawdzania czy plik istnieje
local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Funkcja do bezpiecznego wykonywania poleceń systemowych i pobierania ich statusu
local function exec_cmd(cmd)
    local success, exit_type, code = os.execute(cmd .. " > /dev/null 2>&1")
    if type(success) == "boolean" then
        return success and code == 0
    else
        return success == 0 -- Dla starszych wersji Lua (5.1)
    end
end

-- Funkcja do odczytu wyjścia z komendy
local function get_cmd_output(cmd)
    local handle = io.popen(cmd)
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    return result
end

-- 1. Pobieranie ścieżki do ISO
local iso_path = arg[1]

if not iso_path or iso_path == "" then
    io.write("Podaj ścieżkę do pliku ISO: ")
    io.flush()
    iso_path = io.read()
end

-- Rozwinięcie tyldy (~) jeśli występuje
local home = os.getenv("HOME") or ""
iso_path = iso_path:gsub("^~", home)

if not file_exists(iso_path) then
    log_error("Plik '" .. iso_path .. "' nie istnieje lub brak do niego dostępu.")
    os.exit(1)
end

log_info("Rozpoczynam analizę obrazu: " .. iso_path)
print(string.rep("-", 50))

-- 2. Sprawdzanie wymaganych narzędzi
local required_tools = { "xorriso", "unsquashfs" }
for _, tool in ipairs(required_tools) do
    if not exec_cmd("command -v " .. tool) then
        log_error("Brak wymaganego narzędzia systemowego: " .. tool)
        log_info("Zainstaluj je komendą: sudo apt install xorriso squashfs-tools")
        os.exit(1)
    end
end

-- 3. Pobieranie spisu plików wewnątrz ISO za pomocą xorriso (bez konieczności montowania rootem)
log_info("Odczytywanie struktury plików wewnątrz ISO...")
local list_cmd = string.format("xorriso -osirrax on -indev %q -find / -type f 2>/dev/null", iso_path)
local raw_files = get_cmd_output(list_cmd)

if raw_files == "" then
    log_error("Nie udało się odczytać zawartości pliku ISO przez xorriso.")
    os.exit(1)
end

-- Indeksowanie plików w tablicy Lua
local files_in_iso = {}
for line in raw_files:gmatch("[^\r\n]+") do
    -- Normalizacja ścieżek (usuniecie ewentualnego cudzysłowu lub prefiksów)
    local clean_path = line:match("^'?(.-)'?$")
    files_in_iso[clean_path] = true
end

-- 4. Analiza struktury Debian Live
local errors_count = 0

log_info("Sprawdzanie obecności kluczowych komponentów Live Build...")

-- A. Sprawdzanie obrazu SquashFS
local squashfs_path = "/live/filesystem.squashfs"
if files_in_iso[squashfs_path] then
    log_ok("Znaleziono główny system plików: " .. squashfs_path)
    
    -- Wypakowanie nagłówka SquashFS do pliku tymczasowego celem testu spójności
    local temp_squash = os.tmpname()
    local extract_squash_cmd = string.format(
        "xorriso -osirrax on -indev %q -extract %q %q 2>/dev/null", 
        iso_path, squashfs_path, temp_squash
    )
    
    if exec_cmd(extract_squash_cmd) then
        if exec_cmd("unsquashfs -s " .. temp_squash) then
            log_ok("Nagłówek i nagłówki kompresji SquashFS są prawidłowe.")
        else
            log_error("Obraz SquashFS jest uszkodzony!")
            errors_count = errors_count + 1
        end
        os.remove(temp_squash)
    else
        log_warn("Nie udało się wyekstrahować SquashFS do weryfikacji nagłówków.")
    end
else
    log_error("Brak pliku '/live/filesystem.squashfs'!")
    errors_count = errors_count + 1
end

-- B. Sprawdzanie Jądra i Initrd
local has_kernel = false
local has_initrd = false

for file_path in pairs(files_in_iso) do
    if file_path:match("^/live/vmlinuz") then
        has_kernel = true
    end
    if file_path:match("^/live/initrd%.img") or file_path:match("^/live/initrd") then
        has_initrd = true
    end
end

if has_kernel then
    log_ok("Jądro Linux (vmlinuz) jest obecne w /live.")
else
    log_error("Brak obrazu jądra (vmlinuz) w katalogu /live!")
    errors_count = errors_count + 1
end

if has_initrd then
    log_ok("Obraz RAM-dysku (initrd.img) jest obecny w /live.")
else
    log_error("Brak obrazu initrd w katalogu /live!")
    errors_count = errors_count + 1
end

-- C. Weryfikacja Bootloadera (ISOLINUX / GRUB / EFI)
local has_bootloader = false
for file_path in pairs(files_in_iso) do
    if file_path:match("^/isolinux/") or file_path:match("^/boot/grub/") or file_path:match("^/EFI/") or file_path:match("^/boot/efi%.img") then
        has_bootloader = true
        break
    end
end

if has_bootloader then
    log_ok("Wykryto struktury bootloadera (ISOLINUX / GRUB / EFI).")
else
    log_error("Nie odnaleziono konfiguracji rozruchowej (isolinux/grub/EFI)!")
    errors_count = errors_count + 1
end

-- D. Test sumy kontrolnej md5sum.txt (jeśli dostępna w ISO)
if files_in_iso["/md5sum.txt"] then
    log_info("Weryfikacja wewnętrznego pliku md5sum.txt...")
    local temp_dir = os.tmpname() .. "_dir"
    os.execute("mkdir -p " .. temp_dir)
    
    local extract_all_cmd = string.format("xorriso -osirrax on -indev %q -extract / %q 2>/dev/null", iso_path, temp_dir)
    if exec_cmd(extract_all_cmd) then
        local check_md5_cmd = string.format("cd %q && md5sum -c md5sum.txt --quiet", temp_dir)
        if exec_cmd(check_md5_cmd) then
            log_ok("Wszystkie pliki w ISO zgadzają się z md5sum.txt.")
        else
            log_error("Wykryto niespójność plików na podstawie md5sum.txt!")
            errors_count = errors_count + 1
        end
    end
    os.execute("rm -rf " .. temp_dir)
else
    log_warn("Brak pliku '/md5sum.txt' w ISO. Pomijanie weryfikacji sum kontrolnych.")
end

print(string.rep("-", 50))

-- 5. Podsumowanie
if errors_count == 0 then
    log_ok("Weryfikacja zakończona SUKCESEM. Obraz ISO jest poprawnie zbudowany!")
else
    log_error("Znaleziono błędy podczas weryfikacji. Liczba problemów: " .. errors_count)
end

-- 6. Opcjonalny test uruchomieniowy w QEMU
if exec_cmd("command -v qemu-system-x86_64") then
    print(string.rep("-", 50))
    io.write("Czy chcesz uruchomić testowy rozruch ISO w QEMU? (t/N): ")
    io.flush()
    local ans = io.read()
    if ans:match("^[tTyY]$") then
        log_info("Uruchamianie QEMU...")
        os.execute(string.format("qemu-system-x86_64 -m 2048 -cdrom %q -boot d -enable-kvm 2>/dev/null || qemu-system-x86_64 -m 2048 -cdrom %q -boot d", iso_path, iso_path))
    end
end
