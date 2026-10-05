# Publica/actualiza la app en Posit Connect Cloud (cuenta emilianogonlas).
# Requiere rsconnect >= 1.11 y haber registrado las credenciales de API una vez:
#   rsconnect::connectCloudClientCredentials(clientId=, clientSecret=, accountName="emilianogonlas")
# NO guardar el clientSecret en el repo. Uso: Rscript scripts/deploy_cloud.R (desde la raíz)
rsconnect::deployApp(
  appDir = ".", appPrimaryDoc = "app.R",
  appFiles = c("app.R", "global.R", "R/formato.R", "R/informe.R", "docs/acerca.html",
               "data/app/pares.parquet", "data/app/adjudicaciones.parquet"),
  appName = "compras-estatales-uy", appTitle = "Compras estatales de Uruguay",
  account = "emilianogonlas", server = "connect.posit.cloud",
  forceUpdate = TRUE, launch.browser = FALSE)
