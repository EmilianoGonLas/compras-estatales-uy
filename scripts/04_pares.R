# ============================================================
# 04 — Tabla de vínculos (año x comprador x proveedor x moneda x procedimiento)
# Es lo que la app mantiene en memoria; el detalle por adjudicación se lee
# a demanda de adjudicaciones.parquet. Sólo adjudicaciones activas con proveedor.
# ============================================================
suppressPackageStartupMessages({library(arrow); library(dplyr); library(data.table)})

# --- Montos atípicos -------------------------------------------------------
# La fuente trae montos imposibles (p. ej. un alambrado de UTE por $392 mil
# millones, 2024; un lote de gasa por USD 2.000 M, 2003), probablemente por
# errores de carga del precio unitario. Conviven con megacontratos reales
# (OSE, vialidad PPP), así que NO se borran: se marcan y la app los excluye
# por defecto, con opción de incluirlos. Umbrales por moneda, en unidades de
# esa moneda. Son una regla de plausibilidad, no un juicio sobre cada caso.
UMBRAL <- c(UYU = 5e9, USD = 2e8, EUR = 1.5e8, UYI = 1e9)
UMBRAL_OTRAS <- 2e8

adj <- read_parquet("data/app/adjudicaciones.parquet") |>
  select(-any_of(c("atipico", "descripcion"))) |>   # descripcion: 20 MB que la app no usa
  mutate(atipico = !is.na(monto) & !is.na(moneda) &
           monto >= coalesce(unname(UMBRAL[moneda]), UMBRAL_OTRAS))
write_parquet(adj, "data/app/adjudicaciones.parquet", compression = "zstd")
cat("Atípicas:", sum(adj$atipico), "de", nrow(adj), "\n")

pares <- adj |>
  select(anio, estado, comprador_id, comprador, inciso_id, inciso,
         proveedor_id, proveedor, moneda, monto, tipo, ocid, atipico) |>
  filter(estado == "active", !is.na(proveedor_id), !is.na(anio), anio >= 2002) |>
  mutate(tipo = coalesce(tipo, "Sin dato"), moneda = coalesce(moneda, "s/precio")) |>
  group_by(anio, comprador_id, comprador, inciso_id, inciso, proveedor_id, proveedor,
           moneda, tipo, atipico) |>
  summarise(n = n_distinct(ocid), monto = sum(monto, na.rm = TRUE), .groups = "drop")

write_parquet(pares, "data/app/pares.parquet", compression = "zstd")
cat("pares.parquet:", nrow(pares), "filas,",
    round(file.size("data/app/pares.parquet") / 1e6, 1), "MB\n")

# --- Arranque rápido de la app -------------------------------------------------
# Shiny en la nube apaga la app tras unos minutos sin uso: cada visita "en frío" tiene que
# arrancar R y cargar los datos antes de que el proxy se rinda. Por eso la app NO lee parquet
# al arrancar (cargar arrow + convertir 650 mil filas = ~2 s): lee un .rds con factores
# (0,25 s) y una tabla `meta` con todo lo que antes se calculaba al iniciar.
P <- as.data.table(pares)
for (c in c("comprador_id", "comprador", "inciso_id", "inciso", "proveedor_id", "proveedor", "moneda", "tipo"))
  P[[c]] <- factor(P[[c]])
P[, `:=`(anio = as.integer(anio), n = as.integer(n))]
saveRDS(P, "data/app/pares.rds")

pc <- unique(as.data.table(pares)[, .(proveedor_id, proveedor)])[order(proveedor)]
cc <- unique(as.data.table(pares)[, .(comprador_id, comprador, inciso)])[order(comprador)]
prov_ch <- pc[, .(value = proveedor_id, label = paste0(proveedor, "  [", sub("^R/", "", proveedor_id), "]"))]
comp_ch <- cc[, .(value = comprador_id, label = paste0(comprador, "  (", coalesce(inciso, "s/d"), ")"))]
meta <- list(
  anios = range(pares$anio),
  # sólo las monedas con peso real; el resto queda fuera del selector
  monedas = head(as.data.table(pares)[moneda != "s/precio", .(m = sum(monto)), by = moneda][order(-m)]$moneda, 4),
  ultima_fecha = max(adj$fecha, na.rm = TRUE),
  tipos = sort(unique(pares$tipo)),
  prov_ch = prov_ch, comp_ch = comp_ch,
  foco_ch = rbind(prov_ch[, .(value = paste0("p:", value), label = paste0("[Proveedor] ", label))],
                  comp_ch[, .(value = paste0("e:", value), label = paste0("[Ente] ", label))]))
saveRDS(meta, "data/app/meta.rds")
cat("pares.rds:", round(file.size("data/app/pares.rds") / 1e6, 1), "MB · meta.rds:",
    round(file.size("data/app/meta.rds") / 1e6, 1), "MB\n")
