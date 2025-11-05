## Bluetooth

[bluetoothctl] discoverable on
[bluetoothctl] pairable on
[bluetoothctl] default-agent
[bluetoothctl] agent on


[bluetoothctl]> pair 38:7C:76:5B:F9:0B
Attempting to pair with 38:7C:76:5B:F9:0B
[CHG] Device 38:7C:76:5B:F9:0B Connected: yes
[CHG] Device 38:7C:76:5B:F9:0B Bonded: yes
[CHG] Device 38:7C:76:5B:F9:0B Modalias: bluetooth:v012Dp0011d0000
[CHG] Device 38:7C:76:5B:F9:0B ServicesResolved: yes
[CHG] Device 38:7C:76:5B:F9:0B Paired: yes
Pairing successful

[bluetoothctl]> trust 38:7C:76:5B:F9:0B
[CHG] Device 38:7C:76:5B:F9:0B Trusted: yes
Changing 38:7C:76:5B:F9:0B trust succeeded

[bluetoothctl]> connect 38:7C:76:5B:F9:0B
Attempting to connect to 38:7C:76:5B:F9:0B
[CHG] Device 38:7C:76:5B:F9:0B Connected: yes
[NEW] Endpoint /org/bluez/hci0/dev_38_7C_76_5B_F9_0B/sep1
[NEW] Endpoint /org/bluez/hci0/dev_38_7C_76_5B_F9_0B/sep2
[NEW] Endpoint /org/bluez/hci0/dev_38_7C_76_5B_F9_0B/sep3
[NEW] Transport /org/bluez/hci0/dev_38_7C_76_5B_F9_0B/sep3/fd0
[CHG] Transport /org/bluez/hci0/dev_38_7C_76_5B_F9_0B/sep3/fd0 Delay: 0x0708 (1800)
Connection successful


pw-cli ls Node

        id 104, type PipeWire:Interface:Node/3
                object.serial = "119"
                factory.id = "12"
                client.id = "48"
                device.id = "101"
                priority.session = "1010"
                priority.driver = "1010"
                node.description = "HT-A5000"
                node.name = "bluez_output.38_7C_76_5B_F9_0B.1"
                media.class = "Audio/Sink"