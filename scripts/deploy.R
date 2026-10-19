# deploy.R — Publica/actualiza la app en shinyapps.io (cuenta emilianogonzalez).
# NO contiene credenciales: usa la cuenta registrada en esta máquina.
# Antes, si cambiaron los datos de origen:
#   Rscript scripts/01_descargar_ocds.R && Rscript scripts/03_preparar_datos_app.R && Rscript scripts/04_pares.R
# Uso: Rscript scripts/deploy.R  (SIEMPRE desde la raíz del repo)
rsconnect::deployApp(
  appDir   = ".",
  appFiles = c("app.R", "global.R", "R", "docs/acerca.html", "www", "sass-cache",
               "data/app/pares.rds", "data/app/meta.rds", "data/app/adjudicaciones.parquet"),
  appName        = "ComprasEstatales",
  account        = "emilianogonzalez",
  forceUpdate    = TRUE,
  launch.browser = FALSE
)
