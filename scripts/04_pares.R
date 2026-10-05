# ============================================================
# 04 — Tabla de vínculos (año x comprador x proveedor x moneda x procedimiento)
# Es lo que la app mantiene en memoria; el detalle por adjudicación se lee
# a demanda de adjudicaciones.parquet. Sólo adjudicaciones activas con proveedor.
# ============================================================
suppressPackageStartupMessages({library(arrow); library(dplyr)})

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
