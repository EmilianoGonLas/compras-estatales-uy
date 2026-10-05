# ============================================================
# 03 — OCDS (ZIP anuales de ARCE) -> parquet para la app
#
# Una fila por adjudicación x proveedor x moneda. Los montos NO vienen
# publicados como total: son sum(cantidad x precio unitario) de los ítems
# de cada adjudicación (o award$value cuando el release lo trae).
# Las monedas NO se suman entre sí: el OCDS no trae tipo de cambio.
#
# Uso:  Rscript scripts/03_preparar_datos_app.R [anio_desde] [anio_hasta]
# ============================================================
suppressPackageStartupMessages({library(jsonlite); library(dplyr); library(arrow); library(stringr); library(data.table)})

args  <- suppressWarnings(as.integer(commandArgs(TRUE)))
desde <- if (length(args) >= 1 && !is.na(args[1])) args[1] else 2002L
hasta <- if (length(args) >= 2 && !is.na(args[2])) args[2] else as.integer(format(Sys.Date(), "%Y"))

raw <- "/mnt/Mec/Proyectos/academico/insumos/compras_estatales"
out <- "data/app"; dir.create(out, showWarnings = FALSE, recursive = TRUE)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
`%|NA|%` <- function(a, b) if (length(a) == 0 || is.na(a)) b else a
`%|NAv|%` <- function(a, b) ifelse(is.na(a), b, a)
chr <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else as.character(x[[1]])
num <- function(x) if (is.null(x) || length(x) == 0) NA_real_ else suppressWarnings(as.numeric(x[[1]]))

# ---- extracción vectorizada -------------------------------------------
# Dos tablas planas por release (adjudicaciones e ítems) que se agregan
# una sola vez con data.table; un tibble por adjudicación tardaba horas.
procesar_release <- function(r) {
  aws <- r$awards
  if (is.null(aws) || length(aws) == 0) return(NULL)
  rid <- r$id; ocid <- r$ocid
  provs_party <- Filter(\(p) "supplier" %in% unlist(p$roles), r$parties)
  K <- length(aws)
  A <- vector("list", K); I <- vector("list", K)
  for (k in seq_len(K)) {
    a <- aws[[k]]
    sup <- a$suppliers
    if (length(sup) == 0 && length(provs_party) == 1) sup <- provs_party
    its <- a$items %||% list()
    A[[k]] <- list(rid = rid, k = k, ocid = ocid,
                   comprador_id = chr(r$buyer$id), comprador = chr(r$buyer$name),
                   tag = chr(r$tag), fecha_release = chr(r$date),
                   estado = chr(a$status), fecha = chr(a$date) %|NA|% chr(r$date),
                   prov_id = chr(sup[[1]]$id), prov = chr(sup[[1]]$name))
    if (!is.null(a$value$amount)) {   # monto declarado a nivel adjudicación
      I[[k]] <- list(rid = rid, k = k, real = TRUE, moneda = chr(a$value$currency),
                     monto = num(a$value$amount), desc = chr(r$tender$title))
    } else if (length(its)) {
      I[[k]] <- list(rid = rid, k = k, real = TRUE,
        moneda = vapply(its, \(i) chr(i$unit$value$currency), ""),
        monto  = vapply(its, \(i) num(i$unit$value$amount) * (num(i$quantity) %|NA|% 0), 0),
        desc   = vapply(its, \(i) chr(i$classification$description), ""))
    } else {
      I[[k]] <- list(rid = rid, k = k, real = FALSE, moneda = NA_character_,
                     monto = NA_real_, desc = NA_character_)
    }
  }
  list(A = rbindlist(A), I = rbindlist(I))
}

procesar_tender <- function(r) {
  t <- r$tender; if (is.null(t)) return(NULL)
  list(ocid = r$ocid, tipo = chr(t$procurementMethodDetails), titulo = chr(t$title),
       descripcion = substr(chr(t$description) %|NA|% "", 1, 300),
       fecha_llamado = chr(t$tenderPeriod$startDate) %|NA|% chr(r$date))
}

# ---- recorrer los años ------------------------------------------------
Al <- list(); Il <- list(); lla <- list()
for (anio in desde:hasta) {
  z <- file.path(raw, sprintf("ocds-%d.zip", anio))
  if (!file.exists(z)) { message("Falta ", z); next }
  td <- file.path(tempdir(), anio); unlink(td, recursive = TRUE)
  unzip(z, exdir = td, junkpaths = TRUE)
  fs <- list.files(td, "\\.json$", full.names = TRUE)
  t0 <- Sys.time()
  for (f in fs) {
    rl <- fromJSON(f, simplifyVector = FALSE)$releases
    res <- Filter(Negate(is.null), lapply(rl, procesar_release))
    Al[[length(Al) + 1]] <- rbindlist(lapply(res, `[[`, "A"))
    Il[[length(Il) + 1]] <- rbindlist(lapply(res, `[[`, "I"))
    lla[[length(lla) + 1]] <- rbindlist(Filter(Negate(is.null), lapply(rl, procesar_tender)))
  }
  unlink(td, recursive = TRUE)
  message(anio, ": ", length(fs), " archivos, ", round(difftime(Sys.time(), t0, units = "secs")), " s")
}
A <- rbindlist(Al); I <- rbindlist(Il); lla <- rbindlist(lla)

# agregar ítems -> una fila por adjudicación x moneda
agg <- I[, .(n_items = sum(real), n_sin_precio = sum(real & is.na(monto)),
             objeto = desc[which.max(fifelse(is.na(monto), -1, monto))],
             monto = if (all(is.na(monto))) NA_real_ else sum(monto, na.rm = TRUE)),
         by = .(rid, k, moneda)]
adj <- as_tibble(merge(A, agg, by = c("rid", "k")))
lla <- as_tibble(lla)
cat("Filas crudas:", nrow(adj), "adjudicaciones;", nrow(lla), "llamados\n")

# ---- limpieza ---------------------------------------------------------
llamados <- lla |> filter(!is.na(tipo) | !is.na(titulo)) |>
  arrange(fecha_llamado) |> group_by(ocid) |>
  summarise(across(c(tipo, titulo, descripcion, fecha_llamado), \(x) first(na.omit(x))), .groups = "drop")

ue <- readr::read_csv("data/codiguera_ue.csv", show_col_types = FALSE)
inc <- readr::read_csv("data/codiguera_incisos.csv", show_col_types = FALSE)

adj <- adj |>
  mutate(fecha = as.Date(substr(fecha, 1, 10)),
         tag = as.character(tag),
         anio = as.integer(format(fecha, "%Y")),
         inciso_id = str_extract(comprador_id, "^[^-]+")) |>
  # la última versión de cada (ocid, proveedor, moneda) manda
  arrange(ocid, prov_id, moneda, fecha_release) |>
  group_by(ocid, prov_id, moneda) |> slice_tail(n = 1) |> ungroup()

# Nombre canónico = el más reciente de cada id (los nombres cambian)
canon <- function(d, id, nom) {
  d |> filter(!is.na(.data[[id]])) |> arrange(desc(fecha)) |>
    distinct(.data[[id]], .keep_all = TRUE) |> select(all_of(c(id, nom)))
}
prov_nom <- canon(adj, "prov_id", "prov") |> rename(proveedor = prov)
comp_nom <- canon(adj, "comprador_id", "comprador") |> rename(comprador_n = comprador)

adj <- adj |> select(-prov) |>
  left_join(prov_nom, by = "prov_id") |>
  left_join(comp_nom, by = "comprador_id") |>
  mutate(comprador = comprador_n %|NAv|% comprador) |> select(-comprador_n) |>
  left_join(mutate(inc, inciso_id = as.character(inciso_id)), by = "inciso_id") |>
  left_join(llamados |> select(ocid, tipo, titulo, descripcion), by = "ocid") |>
  mutate(proveedor_id = prov_id,
         tipo_id = case_when(str_starts(proveedor_id %|NAv|% "", "R/") ~ "RUPE (RUT)",
                             str_starts(proveedor_id %|NAv|% "", "X/") ~ "Extranjero",
                             TRUE ~ "Otro / sin dato")) |>
  select(ocid, anio, fecha, estado, comprador_id, comprador, inciso_id, inciso,
         proveedor_id, proveedor, tipo_id, moneda, monto, n_items, n_sin_precio,
         objeto, tipo, titulo, descripcion) |>
  arrange(proveedor_id, fecha)

write_parquet(adj, file.path(out, "adjudicaciones.parquet"), compression = "zstd")
cat("adjudicaciones.parquet:", nrow(adj), "filas,",
    round(file.size(file.path(out, "adjudicaciones.parquet")) / 1e6, 1), "MB\n")
