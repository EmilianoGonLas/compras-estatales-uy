# ============================================================
# Compras estatales — Uruguay: dependencias y datos globales
#
# Pensado para arrancar rápido: en la nube la app se apaga tras unos minutos sin uso y cada
# visita "en frío" tiene que levantarse antes de que el proxy se rinda (error «upstream connect
# error … connection timeout»). Por eso acá NO se carga arrow ni se lee parquet: los vínculos
# vienen de un .rds con factores y todo lo precalculado de `meta.rds` (ver scripts/04_pares.R).
# ============================================================
suppressPackageStartupMessages({
  library(shiny); library(bslib); library(dplyr)
  library(DT); library(visNetwork); library(data.table)
})

# Caché de estilos empaquetada: bslib compila Bootstrap + el tema con Sass en CADA arranque
# (~1,5 s en frío). `sass-cache/` se genera una vez en local (Rscript scripts/precalentar_css.R)
# y viaja con la app, así el servidor sólo lee el CSS ya compilado.
if (dir.exists("sass-cache")) options(sass.cache = sass::sass_file_cache("sass-cache"))

# Vínculos (comprador x proveedor x año x moneda x procedimiento): en memoria.
# Se guardan como factores (se leen 8 veces más rápido) y se pasan a texto acá.
pares <- readRDS("data/app/pares.rds")
for (c in names(pares)[vapply(pares, is.factor, logical(1))]) set(pares, j = c, value = as.character(pares[[c]]))

meta <- readRDS("data/app/meta.rds")
anios <- meta$anios; monedas <- meta$monedas; ULTIMA_FECHA <- meta$ultima_fecha
prov_ch <- meta$prov_ch; comp_ch <- meta$comp_ch; foco_ch <- meta$foco_ch   # opciones de los buscadores
TIPOS <- meta$tipos

# Detalle por adjudicación (38 MB): se abre recién cuando alguien pide una ficha o un informe,
# y es ahí cuando se carga arrow (~0,5 s). No pesa en el arranque.
.adj <- NULL
adj_ds <- function() {
  if (is.null(.adj)) {
    suppressPackageStartupMessages(library(arrow))
    .adj <<- open_dataset("data/app/adjudicaciones.parquet")
  }
  .adj
}

source("R/formato.R", encoding = "UTF-8")
source("R/graficos.R", encoding = "UTF-8")
source("R/informe.R",  encoding = "UTF-8")
