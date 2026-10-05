# ============================================================
# 01 — Descarga los ZIP anuales OCDS de ARCE (Compras Estatales)
# Fuente: catalogodatos.gub.uy, dataset arce-datos-historicos-de-compras
# Idempotente: no vuelve a bajar lo que ya está (salvo el año en curso).
# ============================================================
suppressPackageStartupMessages({library(httr2); library(jsonlite)})

dest <- "/mnt/Mec/Proyectos/academico/insumos/compras_estatales"
dir.create(dest, showWarnings = FALSE, recursive = TRUE)

pkg <- request("https://catalogodatos.gub.uy/api/3/action/package_show") |>
  req_url_query(id = "arce-datos-historicos-de-compras") |>
  req_perform() |> resp_body_json()

recs <- pkg$result$resources
cat("Dataset modificado:", pkg$result$metadata_modified, "\n")

for (r in recs) {
  anio <- sub(".*?(\\d{4}).*", "\\1", r$name)
  f <- file.path(dest, sprintf("ocds-%s.zip", anio))
  actual <- as.integer(anio) >= as.integer(format(Sys.Date(), "%Y")) - 1
  if (file.exists(f) && !actual && file.size(f) == as.numeric(r$size)) next
  cat("Bajando", anio, "...\n")
  request(r$url) |> req_timeout(900) |> req_retry(max_tries = 4, retry_on_failure = TRUE) |>
    req_perform(path = f)
}
cat("Listo:", length(list.files(dest, "zip$")), "zips en", dest, "\n")
