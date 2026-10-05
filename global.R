# ============================================================
# Compras estatales — Uruguay: dependencias y datos globales
# ============================================================
suppressPackageStartupMessages({
  library(shiny); library(bslib); library(arrow); library(dplyr); library(tidyr)
  library(plotly); library(DT); library(visNetwork); library(ggplot2)
  library(gridExtra); library(scales); library(data.table)
})

# Vínculos (comprador x proveedor x año x moneda x procedimiento): en memoria.
pares <- as.data.table(read_parquet("data/app/pares.parquet"))
# Detalle por adjudicación: se consulta a demanda, no se carga.
adj_ds <- open_dataset("data/app/adjudicaciones.parquet")

anios <- range(pares$anio)
# Sólo las monedas con peso real; el resto queda fuera del selector.
monedas <- pares[moneda != "s/precio", .(m = sum(monto)), by = moneda][order(-m)]$moneda
monedas <- head(monedas, 4)

prov_choices <- unique(pares[, .(proveedor_id, proveedor)])[order(proveedor)]
comp_choices <- unique(pares[, .(comprador_id, comprador, inciso)])[order(comprador)]
ULTIMA_FECHA <- as.Date(arrow::open_dataset("data/app/adjudicaciones.parquet") |>
  summarise(f = max(fecha, na.rm = TRUE)) |> collect() |> pull(f))

source("R/formato.R", encoding = "UTF-8")
source("R/informe.R",  encoding = "UTF-8")
