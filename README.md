# KRaidMonitor Plasmoid

KRaidMonitor is a KDE Plasma widget that monitors the status of RAID arrays on your system. It provides a quick and easy way to check the health of your RAID setup directly from your desktop.

**Note:** All code in this project was generated using AI assistance as a personal experiment.

## Features

- Automatically detects RAID arrays on your system
- Displays the current status of the selected RAID array
- Shows different icons based on the RAID array's state (OK, Syncing, Degraded, Error)
- Configurable update interval

## Requirements

- KDE Plasma 5.15 or higher
- Qt 5.15 or higher
- KDE Frameworks 5.70 or higher
- CMake 3.16 or higher
- Extra CMake Modules (ECM)

## Building and Installing

1. Make sure you have the required dependencies installed. On Ubuntu or Debian-based systems, you can install them with:
   `sudo apt install cmake extra-cmake-modules qtbase5-dev libkf5plasma-dev libkf5i18n-dev libkf5service-dev libkf5package-dev libkf5declarative-dev`

2. Clone the repository: `git clone https://github.com/yourusername/kraidmonitor.git cd kraidmonitor`

3. Create a build directory and run CMake:
   `mkdir build cd build cmake ..`

4. Build the plasmoid: `make`

5. Install the plasmoid: `sudo make install`

6. Restart the Plasma shell: `kquitapp5 plasmashell && kstart5 plasmashell`

## Usage

1. Right-click on your desktop or panel and select "Add Widgets"

2. Search for "RAID Monitor" and add it to your desktop or panel

3. The widget will automatically detect and monitor your RAID arrays To configure the update interval:

- Right-click on the widget and select "Configure RAID Monitor"
- Adjust the "Update interval" setting as desired

## Troubleshooting

If the widget doesn't show up after installation, try running: `kpackagetool5 -l | grep raidmonitor`
If the output is empty, manually install the package: `kpackagetool5 -t Plasma/Applet -i package/`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is dedicated to the public domain under the Creative Commons CC0 1.0 Universal (CC0 1.0) Public Domain Dedication.

You can copy, modify, distribute and perform the work, even for commercial purposes, all without asking permission.

For more information about CC0, visit: https://creativecommons.org/publicdomain/zero/1.0/
