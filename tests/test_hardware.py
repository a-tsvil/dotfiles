import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'stow/waybar/.config/waybar/scripts'


class HardwareTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-hardware-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ':' + os.environ['PATH'])
        nmcli = self.bin / 'nmcli'
        nmcli.write_text('''#!/usr/bin/env bash
case "$*" in
  *" device status") printf '%s\\n' "$MOCK_DEVICES" ;;
  *" device show "*)
    device="${!#}"
    printf '%s' "$device" > "$HOME/selected-interface"
    case "$device" in eth*) type=ethernet ;; *) type=wifi ;; esac
    printf 'GENERAL.TYPE:%s\\nGENERAL.STATE:100 (connected)\\nGENERAL.CONNECTION:Example\\nIP4.ADDRESS[1]:192.0.2.2/24\\n' "$type"
    ;;
  "radio wifi") echo enabled ;;
  *" device wifi list "*) echo '*:Example:80' ;;
esac
''')
        nmcli.chmod(0o755)

    def network(self, devices, override=None):
        self.env['MOCK_DEVICES'] = devices
        if override:
            config = self.home / '.config/desktop/host.env'
            config.parent.mkdir(parents=True)
            config.write_text('NETWORK_INTERFACE=' + override + '\n')
        result = subprocess.run(['bash', str(SCRIPTS / 'network-status.sh')], env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines()[-1], 'connected')
        return (self.home / 'selected-interface').read_text()

    def test_connected_wifi_is_preferred(self):
        self.assertEqual(self.network('eth0:ethernet:connected\nwlan0:wifi:disconnected\nwlan1:wifi:connected'), 'wlan1')

    def test_connected_ethernet_fallback(self):
        self.assertEqual(self.network('wlan0:wifi:disconnected\neth0:ethernet:connected'), 'eth0')

    def test_explicit_host_interface(self):
        self.assertEqual(self.network('wlan0:wifi:connected', override='wlan9'), 'wlan9')

    def battery_script(self):
        supply = self.home / 'power_supply'
        supply.mkdir()
        script = self.home / 'battery-status.sh'
        script.write_text((SCRIPTS / 'battery-status.sh').read_text().replace('/sys/class/power_supply', str(supply)))
        return supply, script

    def test_nondefault_battery_discovery(self):
        supply, script = self.battery_script()
        battery = supply / 'BAT3'
        battery.mkdir()
        for name, text in [('type', 'Battery'), ('capacity', '65'), ('status', 'Charging')]:
            (battery / name).write_text(text + '\n')
        result = subprocess.run(['bash', str(script)], env=self.env, text=True, capture_output=True, check=True)
        lines = result.stdout.splitlines()
        self.assertIn('65%', lines[0])
        self.assertIn('BAT3', lines[1])
        self.assertEqual(lines[2], 'charging')

    def test_desktop_without_battery(self):
        _, script = self.battery_script()
        result = subprocess.run(['bash', str(script)], env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(), ['', 'No battery detected', 'missing'])
