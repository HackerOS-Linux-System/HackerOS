local iso_path = "./HackerOS-V4.9.iso"

-- Budujemy polecenie QEMU
local cmd = string.format(
    "qemu-system-x86_64 -m 4G -enable-kvm " ..
    "-device qemu-xhci,id=xhci " ..
    "-drive file=%s,format=raw,if=none,id=usbdisk " ..
    "-device usb-storage,bus=xhci.0,drive=usbdisk,bootindex=0 " ..
    "-snapshot -boot menu=on",
    iso_path
)

-- Uruchamiamy komendę
print("Uruchamianie QEMU z obrazem: " .. iso_path)
local success, exit_type, code = os.execute(cmd)

if success then
    print("QEMU zostało zamknięte prawidłowo.")
else
    print("Błąd podczas uruchamiania QEMU (kod wyjścia: " .. tostring(code) .. ")")
end
