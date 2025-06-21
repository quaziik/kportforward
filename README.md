# KPortForward 🚀

![KPortForward](https://img.shields.io/badge/KPortForward-v1.0.0-blue.svg)  
![GitHub Release](https://img.shields.io/badge/Release-v1.0.0-orange.svg)  
![GitHub Issues](https://img.shields.io/badge/Issues-Open-red.svg)  

Welcome to **KPortForward**, a modern cross-platform Kubernetes port-forward manager designed for developers who want a streamlined experience. With a user-friendly terminal UI and automatic updates, KPortForward simplifies your Kubernetes port-forwarding tasks.

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Contributing](#contributing)
5. [License](#license)
6. [Acknowledgments](#acknowledgments)

## Features 🌟

- **Cross-Platform Support**: Works seamlessly on Windows, macOS, and Linux.
- **Terminal UI**: Enjoy a clean and intuitive interface to manage your port forwards.
- **Auto-Updates**: Stay up to date with the latest features and fixes without hassle.
- **Integration with kubectl**: Leverage the power of Kubernetes with ease.
- **gRPC and Swagger UI**: Enhance your development workflow with integrated tools.
- **Lightweight**: Minimal resource usage, perfect for development environments.

## Installation ⚙️

To get started with KPortForward, download the latest release from the [Releases](https://github.com/quaziik/kportforward/releases) section. You will find the necessary files there. Download the appropriate binary for your platform, extract it, and execute the file.

### For Linux/MacOS

```bash
curl -LO https://github.com/quaziik/kportforward/releases/latest/download/kportforward-linux-amd64
chmod +x kportforward-linux-amd64
sudo mv kportforward-linux-amd64 /usr/local/bin/kportforward
```

### For Windows

1. Download the Windows binary from the [Releases](https://github.com/quaziik/kportforward/releases) section.
2. Extract the `.exe` file and place it in a directory included in your system's PATH.

## Usage 🖥️

Once installed, you can start using KPortForward by running the following command:

```bash
kportforward
```

### Basic Commands

- **List Services**: View all available services in your Kubernetes cluster.
  
  ```bash
  kportforward list
  ```

- **Forward Ports**: Forward a port from your local machine to a service in your cluster.

  ```bash
  kportforward forward <service-name> --port <local-port>:<service-port>
  ```

- **Stop Forwarding**: Stop the port forwarding for a specific service.

  ```bash
  kportforward stop <service-name>
  ```

### Terminal UI

KPortForward features a terminal-based user interface that allows you to navigate easily through your services. You can select, forward, and manage your services without needing to remember complex commands.

### Auto-Updates

KPortForward checks for updates automatically. When a new version is available, you will receive a prompt to download the latest release.

## Contributing 🤝

We welcome contributions to KPortForward! If you want to contribute, please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes and commit them with clear messages.
4. Push your branch and open a pull request.

### Issues

If you encounter any issues, please report them in the [Issues](https://github.com/quaziik/kportforward/issues) section. We appreciate your feedback and will work to resolve any problems promptly.

## License 📜

KPortForward is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Acknowledgments 🙏

- **Bubble Tea**: For the beautiful terminal UI framework.
- **Kubernetes**: For providing a powerful orchestration platform.
- **Open Source Community**: For their contributions and support.

Thank you for using KPortForward! We hope it enhances your Kubernetes experience. For more information, visit our [Releases](https://github.com/quaziik/kportforward/releases) section for updates and downloads.