#!/bin/bash

# === Configuration ===
# URL de la API que se va a probar
API_URL="http://localhost:8000"
# Número total de ciclos de petición (POST /encode -> GET /decode) a realizar
NUM_REQUESTS=100
# Base para generar IDs únicos (se usará desde UNIQUE_ID_BASE + 1)
UNIQUE_ID_BASE=1000000
# Número máximo de peticiones que se ejecutarán en paralelo
MAX_PARALLEL_REQUESTS=1
# Tiempo máximo de espera (en segundos) para cada petición individual (POST o GET)
REQUEST_TIMEOUT=3
# =====================

# --- Dependency Check ---
# Verifica si las herramientas necesarias están instaladas
if ! command -v curl &> /dev/null; then
    echo "Error: curl no está instalado." >&2
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "Error: jq no está instalado (necesario para extraer cto_id)." >&2
    exit 1
fi
if ! command -v tr &> /dev/null; then
    echo "Error: tr no está instalado." >&2
    exit 1
fi
if ! command -v head &> /dev/null; then
    echo "Error: head no está instalado." >&2
    exit 1
fi
if ! command -v fold &> /dev/null; then
    echo "Error: fold no está instalado." >&2
    exit 1
fi
if ! command -v bc &> /dev/null; then
    echo "Error: bc no está instalado (necesario para calcular el tiempo)." >&2
    exit 1
fi
if ! command -v date &> /dev/null; then
    echo "Error: date no está instalado." >&2
    exit 1
fi
if ! command -v timeout &> /dev/null; then
    echo "Error: timeout no está instalado (parte de coreutils)." >&2
    exit 1
fi

# --- Initialization ---
echo "Iniciando prueba de carga de la API (versión simplificada)..."
echo "API objetivo: $API_URL"
echo "Número de ciclos de petición: $NUM_REQUESTS"
echo "Máximo de peticiones paralelas: $MAX_PARALLEL_REQUESTS"
echo "---"

# Guarda el tiempo de inicio con precisión de nanosegundos
start_time=$(date +%s.%N)

# --- Function to handle a single request cycle ---
# Realiza un ciclo completo: POST /encode y luego GET /decode
perform_request_cycle() {
    local i=$1
    local current_unique_id=$(($UNIQUE_ID_BASE + i))
    # Genera un nombre aleatorio de 10 caracteres alfanuméricos
    local current_cto_name=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 10 | head -n 1)

    # Verifica si se pudo generar el nombre correctamente
    if [[ ${#current_cto_name} -ne 10 ]]; then
        echo "[Ciclo $i / $NUM_REQUESTS] ERROR: No se pudo generar cto_name de 10 caracteres." >&2
        return # No continuar este ciclo
    fi

    # --- Petición POST /encode ---
    local post_payload="{\"id\": $current_unique_id, \"name\": \"$current_cto_name\"}"
    local post_response
    # Ejecuta curl con timeout, capturando cuerpo y código HTTP
    post_response=$(timeout "$REQUEST_TIMEOUT" curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$post_payload" \
        "$API_URL/encode")
    local post_curl_exit_code=$? # Guarda el código de salida de curl/timeout

    # Comprueba si hubo timeout o error de curl en el POST
    if [[ $post_curl_exit_code -ne 0 ]]; then
        if [[ $post_curl_exit_code -eq 124 ]]; then # Código de salida específico de timeout
             echo "[Ciclo $i / $NUM_REQUESTS] ERROR: Timeout en POST /encode." >&2
        else
             echo "[Ciclo $i / $NUM_REQUESTS] ERROR: Fallo en curl durante POST /encode (código: $post_curl_exit_code)." >&2
        fi
        return # No continuar este ciclo
    fi

    # Extrae el código HTTP y el cuerpo de la respuesta POST
    local post_http_status=$(echo "$post_response" | tail -n1)
    local post_body=$(echo "$post_response" | sed '$d')

    # Comprueba si el código HTTP del POST no fue 200 OK
    if [[ "$post_http_status" -ne 200 ]]; then
        echo "[Ciclo $i / $NUM_REQUESTS] ERROR: POST /encode devolvió estado $post_http_status." >&2
        # Podrías imprimir el cuerpo si quieres depurar: echo "Body: $post_body" >&2
        return # No continuar este ciclo
    fi

    # Extrae el 'cto_id' de la respuesta JSON del POST
    local cto_id=$(echo "$post_body" | jq -r '.cto_id')
    # Comprueba si se pudo extraer el 'cto_id'
    if [[ -z "$cto_id" || "$cto_id" == "null" ]]; then
        echo "[Ciclo $i / $NUM_REQUESTS] ERROR: No se pudo extraer 'cto_id' de la respuesta POST." >&2
        return # No continuar este ciclo
    fi

    # --- Petición GET /decode/{cto_id} ---
    local get_response
    # Ejecuta curl con timeout para el GET
    get_response=$(timeout "$REQUEST_TIMEOUT" curl -s -w "\n%{http_code}" -X GET \
        "$API_URL/decode/$cto_id")
    local get_curl_exit_code=$? # Guarda el código de salida de curl/timeout

    # Comprueba si hubo timeout o error de curl en el GET
    if [[ $get_curl_exit_code -ne 0 ]]; then
         if [[ $get_curl_exit_code -eq 124 ]]; then # Código de salida específico de timeout
            echo "[Ciclo $i / $NUM_REQUESTS] ERROR: Timeout en GET /decode/$cto_id." >&2
         else
            echo "[Ciclo $i / $NUM_REQUESTS] ERROR: Fallo en curl durante GET /decode/$cto_id (código: $get_curl_exit_code)." >&2
         fi
        return # No continuar este ciclo
    fi

    # Extrae el código HTTP de la respuesta GET
    local get_http_status=$(echo "$get_response" | tail -n1)
    # local get_body=$(echo "$get_response" | sed '$d') # Cuerpo no necesario en esta versión

    # Comprueba si el código HTTP del GET no fue 200 OK
    if [[ "$get_http_status" -ne 200 ]]; then
        echo "[Ciclo $i / $NUM_REQUESTS] ERROR: GET /decode/$cto_id devolvió estado $get_http_status." >&2
        return # No continuar este ciclo
    fi

    # Si llegamos aquí, el ciclo POST -> GET se completó sin timeouts y con códigos 200
    # No se valida el contenido de la respuesta GET en esta versión.
    # No se incrementa ningún contador de éxito.

} # Fin de la función perform_request_cycle

# --- Main Test Loop ---
active_jobs=0
# Itera para lanzar el número total de ciclos de petición
for (( i=1; i<=$NUM_REQUESTS; i++ )); do
    # Ejecuta la función del ciclo en segundo plano (&)
    perform_request_cycle "$i" &
    ((active_jobs++)) # Incrementa el contador de trabajos activos

    # Si se alcanza el límite de trabajos paralelos, espera a que uno termine
    if (( active_jobs >= MAX_PARALLEL_REQUESTS )); then
        wait -n # Espera a que el próximo trabajo en segundo plano finalice
        ((active_jobs--)) # Decrementa el contador de trabajos activos
    fi
done

# Espera a que todos los trabajos en segundo plano restantes terminen
wait

# --- Results ---
# Guarda el tiempo de finalización con precisión de nanosegundos
end_time=$(date +%s.%N)
# Calcula la diferencia de tiempo usando bc para manejar decimales
total_time=$(echo "$end_time - $start_time" | bc -l)

echo "---"
echo "Prueba de Carga Finalizada (Versión Simplificada)"
echo "----------------------------------------"
echo "Resumen:"
echo "  Ciclos de Petición Intentados: $NUM_REQUESTS"
# LC_NUMERIC=C asegura que el punto decimal sea '.' para bc y printf
LC_NUMERIC=C printf "  Tiempo Total Transcurrido: %.3f segundos\n" "$total_time"
echo "----------------------------------------"
echo "(Nota: Este script no valida la corrección de las respuestas, solo mide el tiempo y reporta errores básicos como timeouts o códigos HTTP no 200)."

# Siempre sale con 0, ya que no estamos validando la lógica de negocio
exit 0
