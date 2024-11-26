# zUI - A UI Kit for JetZig Framework 🚀

zUI is a modern and lightweight UI kit designed for the [JetZig](https://github.com/JetZig/jetzig) framework, leveraging the power and simplicity of Zig. zUI provides a collection of reusable components, styles, and utilities to speed up your development process and deliver beautiful, consistent user interfaces.

## Basic Features

- **Super Lightweight:** Minimal overhead for fast performance. Targeting less than 50kb load for whole page.
- **Customizable:** Easily adaptable to your design needs.
- **Component-Based:** Ready-to-use, pre-styled components, pages, partials, and icons.
- **Seamless Integration:** Built specifically for the JetZig framework.

## Pro Features / Work in Progress ✨

- **Database Integration:** Support for PostgreSQL with ready-made CRUD operations, infinite scroll, pagination, and more.
- **Themes:** Multi-color options with dark/light mode support.
- **Built-in Auth/Security:** Features like JWT, session cookies, and role-based workflows.
- **Premium Fully-Integrated Features:** Components for blogs, product catalogs, premium dashboards with charts, and more.
- **Docker Compose & Kubernetes Configurations:** Comprehensive guides, bash scripts, and full-fledged Kubernetes setup.

## Getting Started 🛠️

Follow these steps to set up zUI and integrate it into your JetZig project.

### Prerequisites

- **Zig Compiler**: [Download Zig](https://ziglang.org/download/)
- **JetZig Framework**: [JetZig Installation Guide](https://www.jetzig.dev/downloads.html)

### Installation

Clone the repository into your project:

```bash
git clone https://github.com/thienpow/zui.git
cd zui
nano build.zig.zon
```

1. Ensure the JetZig framework path is correctly configured in the build.zig.zon file.
2. If the JetZig framework is not installed on your system, download the latest version from the JetZig source repository and update the path in the configuration file.
3. Save your changes and exit the editor.

Next, start the server with the following command:
```bash
jetzig server
```

Contributing 🤝

We welcome contributions! Please follow the steps below:

    Fork the repository.
    Create a new branch (git checkout -b feature-branch).
    Commit your changes (git commit -m 'Add new feature').
    Push the branch (git push origin feature-branch).
    Open a Pull Request.

License 📄

zUI is open-sourced under the MIT License.
Feedback and Support 🙌

Have suggestions or need help? Feel free to open an issue or contact us at thienpow@gmail.com.
