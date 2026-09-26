pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.common
import qs.greeter.config

// Real device data for the status panel and the barcode label:
// - ip: public IPv4 address as seen by the internet (asked from external
//   services, so with a VPN it's the VPN exit), otherwise the last known one,
//   otherwise a random one;
// - hostname;
// - deviceCode/deviceId: hardware summary and a stable hash of the device.
Singleton {
    id: root

    Logger {
        id: logger
        name: "DeviceInfo"
    }

    readonly property string hostname: _info.hostname || "localhost"

    // "031.076.099.236": leading zeros are part of the look
    readonly property string ip: _format(_publicIp || _savedIp || _randomIp)
    // "live" | "saved" | "random"
    readonly property string ipSource: _publicIp ? "live" : _savedIp ? "saved" : "random"

    // "X86_64-12C-16G-K7.2": arch, logical cores, RAM (GiB), kernel
    readonly property string deviceCode: _info.code || "UNKNOWN-DEVICE"
    // 128 bits of sha256(machine-id, board, CPU model, physical MACs) as a UUID
    readonly property string deviceId: _formatUuid(_info.hash || "")
    readonly property string deviceLabel: `${deviceCode}|${deviceId}`

    property var _info: ({})
    // local address of the default route: only tells whether the network is up
    property string _localIp: ""
    property string _publicIp: ""
    property string _savedIp: ""
    readonly property string _randomIp: [10, _randomOctet(), _randomOctet(), _randomOctet()].join(".")

    // the greeter user has no writable home: /var/lib/ctos is created by install.sh
    readonly property string _statePath: Settings.isGreetd || Settings.isKiosk ? "/var/lib/ctos/state.json" : Quickshell.statePath("state.json")

    function _randomOctet(): int {
        return 1 + Math.floor(Math.random() * 254);
    }

    function _format(ip: string): string {
        return ip.split(".").map(octet => octet.padStart(3, "0")).join(".");
    }

    function _formatUuid(hex: string): string {
        if (hex.length < 32) {
            return "00000000-0000-0000-0000-000000000000";
        }
        const h = hex.toUpperCase();
        return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
    }

    function _saveIp(ip: string) {
        if (ip === _savedIp) {
            return;
        }
        _savedIp = ip;
        stateFile.setText(JSON.stringify({
            "publicIp": ip
        }));
    }

    FileView {
        id: stateFile
        path: root._statePath
        blockLoading: true

        onLoaded: {
            try {
                const ip = JSON.parse(text()).publicIp || "";
                if (/^\d{1,3}(\.\d{1,3}){3}$/.test(ip)) {
                    root._savedIp = ip;
                }
            } catch (e) {
                logger.warn(`Invalid state file ${path}: ${e}`);
            }
        }

        onSaveFailed: error => logger.warn(`Cannot save ${path}: ${FileViewError.toString(error)}`)
    }

    Process {
        id: infoProcess

        property var collected: ({})

        running: true
        command: ["sh", "-c", `
echo "hostname=$(cat /proc/sys/kernel/hostname)"

arch=$(uname -m | tr '[:lower:]' '[:upper:]')
kernel=$(uname -r | cut -d. -f1,2)
cores=$(nproc)
mem=$(awk '/^MemTotal:/ { printf "%d", $2 / 1048576 + 0.5 }' /proc/meminfo)
echo "code=$arch-\${cores}C-\${mem}G-K$kernel"

{
    cat /etc/machine-id
    cat /sys/class/dmi/id/board_vendor /sys/class/dmi/id/board_name 2>/dev/null
    grep -m1 '^model name' /proc/cpuinfo
    for n in /sys/class/net/*; do [ -e "$n/device" ] && cat "$n/address"; done | sort
} 2>/dev/null | sha256sum | cut -c1-32 | sed 's/^/hash=/'
`]

        stdout: SplitParser {
            onRead: line => {
                const index = line.indexOf("=");
                if (index > 0) {
                    infoProcess.collected[line.slice(0, index)] = line.slice(index + 1).trim();
                }
            }
        }

        onExited: {
            root._info = infoProcess.collected;
            logger.info(`${root.hostname} ${root.deviceLabel}`);
        }
    }

    function _isIpv4(value: string): bool {
        return /^\d{1,3}(\.\d{1,3}){3}$/.test(value);
    }

    // network state: src of the first default route (main table), or the first
    // global address of its device
    Process {
        id: localIpProcess

        property string found: ""

        command: ["sh", "-c", `
route=$(ip -4 route show default table main 2>/dev/null | head -1)
[ -n "$route" ] || exit 0
src=$(echo "$route" | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')
if [ -z "$src" ]; then
    dev=$(echo "$route" | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
    src=$(ip -4 -o addr show dev "$dev" scope global 2>/dev/null | awk '{ split($4, a, "/"); print a[1]; exit }')
fi
echo "$src"
`]

        stdout: SplitParser {
            onRead: line => localIpProcess.found = line.trim()
        }

        onStarted: found = ""

        onExited: {
            const ip = root._isIpv4(found) ? found : "";
            if (ip === root._localIp) {
                return;
            }

            logger.info(`Local IP: ${ip || "offline"}`);
            root._localIp = ip;

            if (ip) {
                // network (re)connected or changed: the public address may be different
                root._fetchPublicIp();
            } else {
                root._publicIp = "";
            }
        }
    }

    // public address: first service that answers with an IPv4 address
    Process {
        id: publicIpProcess

        property string found: ""

        command: ["sh", "-c", `
for url in https://api.ipify.org https://ipv4.icanhazip.com https://ifconfig.me/ip; do
    ip=$(curl -4 -fsS --max-time 4 "$url" 2>/dev/null | tr -d '[:space:]')
    case "$ip" in
        *[!0-9.]* | "") continue ;;
    esac
    echo "$ip"
    exit 0
done
exit 1
`]

        stdout: SplitParser {
            onRead: line => publicIpProcess.found = line.trim()
        }

        onStarted: found = ""

        onExited: {
            const ip = root._isIpv4(found) ? found : "";
            if (!ip) {
                logger.info("Public IP: unavailable");
                root._publicIp = "";
                return;
            }

            if (ip !== root._publicIp) {
                logger.info(`Public IP: ${ip}`);
            }
            root._publicIp = ip;
            root._saveIp(ip);
        }
    }

    function _fetchPublicIp() {
        if (!publicIpProcess.running) {
            publicIpProcess.running = true;
        }
    }

    // the network may come up after the greeter has started
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!localIpProcess.running) {
                localIpProcess.running = true;
            }
        }
    }

    // while online: refresh the public address rarely, retry sooner after a failure
    Timer {
        interval: root._publicIp ? 10 * 60 * 1000 : 30 * 1000
        running: root._localIp !== ""
        repeat: true
        onTriggered: root._fetchPublicIp()
    }
}
