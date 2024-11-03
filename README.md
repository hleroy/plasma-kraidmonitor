# KRaidMonitor Plasmoid

KRaidMonitor is a KDE Plasma widget that monitors the status of RAID arrays on your system. It provides a quick and easy way to check the health of your RAID setup directly from your desktop.

**Note:** All code in this project was generated using AI assistance as a personal experiment.

## Features

- Automatically detects RAID arrays on your system
- Displays the current status of the selected RAID array
- Shows different icons based on the RAID array's state (OK, Syncing, Degraded, Error)
- Configurable update interval

## Requirements

- KDE Plasma 6 or higher
- Qt 6.5 or higher
- KDE Frameworks 6 or higher
- CMake 3.16 or higher
- Extra CMake Modules (ECM)

## Building and Installing

1. Make sure you have the required dependencies installed. On Kubuntu, you can install them with:
   `sudo apt install cmake extra-cmake-modules plasma-sdk qt6-base-dev qt6-declarative-dev qt6-tools-dev libplasma-dev libkf6i18n-dev libkf6service-dev libkf6package-dev plasma-workspace-dev qt6-base-private-dev qt6-declarative-private-dev`

2. Clone the repository: `git clone https://github.com/hleroy/kraidmonitor.git cd kraidmonitor`

3. Create a build directory and run CMake:
   `mkdir build cd build cmake ..`

4. Build the plasmoid: `make`

5. Install the plasmoid: `sudo make install`

6. Restart the Plasma shell: `kquitapp6 plasmashell && kstart plasmashell`

## Usage

1. Right-click on your desktop or panel and select "Add Widgets"

2. Search for "RAID Monitor" and add it to your desktop or panel

3. The widget will automatically detect and monitor your RAID arrays To configure the update interval:

- Right-click on the widget and select "Configure RAID Monitor"
- Adjust the "Update interval" setting as desired

## Troubleshooting

To see errors in the console, use the plasmoid viewer (launched from the root of the repo):
`plasmoidviewer -a package`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is dedicated to the public domain under the Creative Commons CC0 1.0 Universal (CC0 1.0) Public Domain Dedication.

You can copy, modify, distribute and perform the work, even for commercial purposes, all without asking permission.

For more information about CC0, visit: https://creativecommons.org/publicdomain/zero/1.0/
