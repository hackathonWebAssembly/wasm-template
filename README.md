# WASM Hackathon Boilerplate: HTTP Hello World

![WASM Hackathon](docs/logo.png)

Welcome to the WASM Hackathon! This boilerplate provides a simple starting point for building WebAssembly (WASM) applications using [wasmCloud](https://wasmcloud.dev). It includes a "Hello, World!" HTTP endpoint and embedded Swagger UI for API documentation.

## What is wasmCloud?

[wasmCloud](https://wasmcloud.dev) is a platform for building secure, portable, and scalable applications using WebAssembly. It allows you to focus on writing business logic while abstracting away infrastructure concerns.

## Features

- **Hello, World!**: A simple HTTP endpoint (`/hello`) that responds with "Hello, World!".
- **Swagger UI**: Embedded Swagger documentation for your API.
- **Boilerplate**: A minimal setup to help you get started quickly.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Go**: Version 1.23 or later
- **TinyGo**: Version 0.33 or later ([Installation Guide](https://tinygo.org/getting-started/))
- **wash CLI**: Version 0.35.0 ([Installation Guide](https://wasmcloud.com/docs/installation))
- **swag CLI**: Version 1.8.12 or later ([Installation Guide](https://github.com/swaggo/swag))
- **Rust and Cargo**: Install using the following command:
  
  ```bash
  curl https://sh.rustup.rs -sSf | sh
  ```
  
- **wasm-tools**: Install using the following command:

  ```bash
  cargo install --locked wasm-tools
  ```
  
## Building the Component

To build the WebAssembly component, use the `wash` CLI:

```bash
wash build
```

This will generate a `.wasm` file in the `./build` directory.

## Updating Swagger Documentation

If you make changes to the API endpoints or their annotations, you need to regenerate the Swagger documentation. Use the `swag init` command to update the `docs/swagger.json` file:

```bash
swag init -g main.go
```

This command scans the `main.go` file for Swagger annotations and regenerates the OpenAPI specification. Ensure you run this command before rebuilding the component.

## Running with wasmCloud

To deploy and run the component in wasmCloud:

1. Start the wasmCloud host:

   ```bash
   wash up -d
   ```

2. Deploy the component using the `wadm.yaml` manifest file. Make sure to update the file path in the manifest to point to your built `.wasm` file:

   ```bash
   wash app deploy ./wadm.yaml
   ```

3. Test the endpoint by sending a request to the host:

   ```bash
   curl http://localhost:8000/hello
   ```

   You should see the response: `Hello, World!`.

## Exploring the Swagger UI

The boilerplate includes embedded Swagger documentation for your API. Once the component is running, you can access the Swagger UI at:

```
http://localhost:8000/swagger/
```

This provides an interactive interface to explore and test your API.

## Next Steps: Adding Capabilities

Want to extend this example? wasmCloud makes it easy to add capabilities like key-value storage, messaging, or event streams. Check out the [wasmCloud documentation](https://wasmcloud.dev/docs/) to learn more.

---

Happy hacking! 🚀