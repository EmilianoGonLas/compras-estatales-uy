# ============================================================
# 05 — Datos para la Red 3D (www/red3d-data.js)
# Por moneda (UYU, USD) se conservan los pares proveedor–ente de mayor monto
# (UYU: 25.000 pares = 96,6 % del monto; USD: todos) con su detalle por año,
# para que la página filtre años y tope sin consultar al servidor.
# Excluye los montos atípicos (ver 04_pares.R). Índices numéricos para achicar el JSON.
# ============================================================
suppressPackageStartupMessages({library(arrow); library(dplyr); library(jsonlite)})

p <- read_parquet("data/app/pares.parquet") |> filter(!atipico, moneda %in% c("UYU", "USD"))
TOPE <- c(UYU = 25000L, USD = 25000L)

sel <- bind_rows(lapply(names(TOPE), function(m) {
  d <- p |> filter(moneda == m)
  top <- d |> group_by(proveedor_id, comprador_id) |> summarise(t = sum(monto), .groups = "drop") |>
    slice_max(t, n = TOPE[[m]], with_ties = FALSE)
  d |> semi_join(top, by = c("proveedor_id", "comprador_id")) |>
    group_by(moneda, anio, proveedor_id, comprador_id) |>
    summarise(monto = sum(monto), n = sum(n), .groups = "drop")
}))

provs <- p |> filter(proveedor_id %in% sel$proveedor_id) |> arrange(desc(anio)) |>
  distinct(proveedor_id, .keep_all = TRUE) |> select(proveedor_id, proveedor) |> arrange(proveedor_id)
entes <- p |> filter(comprador_id %in% sel$comprador_id) |> arrange(desc(anio)) |>
  distinct(comprador_id, .keep_all = TRUE) |> select(comprador_id, comprador, inciso_id, inciso) |> arrange(comprador_id)
incisos <- entes |> distinct(inciso_id, inciso) |>
  mutate(inciso = coalesce(inciso, ifelse(is.na(inciso_id), "Sin inciso asignado", paste("Inciso", inciso_id)))) |> arrange(as.integer(inciso_id))

ix <- function(v, ref) match(v, ref) - 1L   # índices base 0 para JS
mat <- function(m) { s <- sel |> filter(moneda == m)
  cbind(ix(s$proveedor_id, provs$proveedor_id), ix(s$comprador_id, entes$comprador_id), s$anio, round(s$monto), s$n) }

D <- list(
  generado = format(Sys.Date()),
  anios = range(sel$anio),
  inc = incisos$inciso,
  ent = lapply(seq_len(nrow(entes)), \(i) list(coalesce(entes$comprador[i], "(sin nombre)"), ix(entes$inciso_id[i], incisos$inciso_id))),
  prov = coalesce(provs$proveedor, "(sin nombre)"),
  filas = list(UYU = mat("UYU"), USD = mat("USD"))
)
js <- paste0("window.RED3D=", toJSON(D, auto_unbox = TRUE, digits = NA, matrix = "rowmajor"), ";")
writeLines(js, "www/red3d-data.js", useBytes = TRUE)
cat("filas UYU/USD:", nrow(mat("UYU")), nrow(mat("USD")), "| proveedores:", nrow(provs),
    "| entes:", nrow(entes), "| incisos:", nrow(incisos), "\n")
cat("www/red3d-data.js:", round(file.size("www/red3d-data.js") / 1e6, 2), "MB\n")
