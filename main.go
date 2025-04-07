package main

import (
	"embed"
	"io/fs"
	"net/http"
	"strings"

	"go.wasmcloud.dev/component/log/wasilog"
	"go.wasmcloud.dev/component/net/wasihttp"
)

// Embed generated swagger spec from the 'docs' directory created by 'swag init'
//go:embed docs/swagger.json
var swaggerSpec embed.FS

// Embed Swagger UI static files from the 'swagger_ui_dist' directory
// Ensure 'swagger_ui_dist/index.html' has the url parameter pointing to "/swagger/doc.json"
//go:embed swagger_ui_dist/*
var swaggerUIFiles embed.FS

// swaggerUIFS holds the http.FileSystem reference for the embedded Swagger UI files.
var swaggerUIFS http.FileSystem

// --- Swagger API Documentation (Annotations used by 'swag init') ---
// @title           Hackathon Boilerplate API
// @version         1.0
// @description     This API provides a boilerplate for hackathon projects with a simple "Hello, World!" endpoint and Swagger UI.
// @termsOfService  http://swagger.io/terms/

// @contact.name   API Support
// @contact.url    http://www.example.com/support
// @contact.email  support@example.com

// @license.name  Apache 2.0
// @license.url   http://www.apache.org/licenses/LICENSE-2.0.html

// @host      localhost:8000
// @BasePath  /
// @schemes   http https

// init runs once when the component starts.
// It sets up the embedded filesystem for Swagger UI and registers the main HTTP handler.
func init() {
    // Create an http.FileSystem pointing to the "swagger_ui_dist" subdirectory
    // within the embedded swaggerUIFiles filesystem.
    subFS, err := fs.Sub(swaggerUIFiles, "swagger_ui_dist")
    if err != nil {
        panic("FATAL: Failed to create sub-filesystem for Swagger UI: " + err.Error())
    }
    swaggerUIFS = http.FS(subFS)

    // Register the main HTTP handler function with the wasihttp component interface.
    wasihttp.HandleFunc(handler)
}

// handler is the main entry point for all incoming HTTP requests.
// It routes requests to the appropriate handler based on the path and method.
func handler(w http.ResponseWriter, r *http.Request) {
    logger := wasilog.ContextLogger("handler")
    logger.Info("Request received", "method", r.Method, "path", r.URL.Path)

    // Route for serving the OpenAPI specification (swagger.json)
    if r.URL.Path == "/swagger/doc.json" && r.Method == http.MethodGet {
        handleSwaggerSpec(w, r)
        return
    }

    // Route for serving the Swagger UI static files
    if strings.HasPrefix(r.URL.Path, "/swagger/") || r.URL.Path == "/swagger" {
        if r.URL.Path == "/swagger" {
            http.Redirect(w, r, "/swagger/", http.StatusMovedPermanently)
            return
        }
        fsHandler := http.StripPrefix("/swagger/", http.FileServer(swaggerUIFS))
        fsHandler.ServeHTTP(w, r)
        return
    }

    // Example "Hello, World!" endpoint
    if r.URL.Path == "/hello" && r.Method == http.MethodGet {
        handleHelloWorld(w, r)
        return
    }

    // Fallback: Not Found
    logger.Warn("Endpoint not found")
    http.Error(w, "Endpoint not found: "+r.URL.Path, http.StatusNotFound)
}

// handleSwaggerSpec serves the embedded docs/swagger.json file.
func handleSwaggerSpec(w http.ResponseWriter, r *http.Request) {
    logger := wasilog.ContextLogger("handleSwaggerSpec")
    w.Header().Set("Content-Type", "application/json")

    spec, err := swaggerSpec.ReadFile("docs/swagger.json")
    if err != nil {
        logger.Error("Could not read embedded swagger spec", "error", err)
        http.Error(w, "Could not read embedded swagger spec", http.StatusInternalServerError)
        return
    }
    _, writeErr := w.Write(spec)
    if writeErr != nil {
        logger.Error("Failed to write swagger spec to response", "error", writeErr)
    }
}

// handleHelloWorld is a simple example handler that returns "Hello, World!".
// @Summary      Hello World Endpoint
// @Description  Returns a simple "Hello, World!" message.
// @Tags         Example
// @Produce      plain
// @Success      200 {string} string "Hello, World!"
// @Router       /hello [get]
func handleHelloWorld(w http.ResponseWriter, r *http.Request) {
    logger := wasilog.ContextLogger("handleHelloWorld")
    w.Header().Set("Content-Type", "text/plain")
    w.WriteHeader(http.StatusOK)
    _, err := w.Write([]byte("Hello, World!"))
    if err != nil {
        logger.Error("Failed to write Hello, World! response", "error", err)
    }
}

// main is the entry point for a standard Go program, but in a wasihttp
// component context, the actual execution starts via the HTTP handler
// registered in the init() function.
func main() {
    logger := wasilog.ContextLogger("main")
    logger.Info("Main function called (likely no-op in wasihttp context)")
}