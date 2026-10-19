# Prueba de humo del servidor Shiny sin navegador: ejercita todas las salidas, en modo oscuro y claro.
# Uso (desde la raíz):  Rscript scripts/probar_app.R
suppressPackageStartupMessages(library(shiny))
app <- source("app.R", encoding = "UTF-8")$value
testServer(app, {
  ok <- 0L; mal <- 0L
  chk <- function(nm, expr) {
    r <- tryCatch({ force(expr); "OK" }, error = function(e) paste("ERROR:", conditionMessage(e)))
    if (r == "OK") ok <<- ok + 1L else { mal <<- mal + 1L; cat(sprintf("%-26s %s\n", nm, r)) } }
  for (modo in c("dark", "light")) {
    session$setInputs(moneda = "UYU", anios = c(2021, 2025), tipo = "", atipicos = FALSE, modo = modo,
                      prov = "R/080115970019", comp = "61-1", n_red = 20, red_foco = "")
    for (o in c("k1", "k2", "k3", "k4", "p_serie", "p_top", "p_tipos", "t_prov", "t_comp", "ficha_prov", "ficha_comp",
                "f_top_proveedor", "f_serie_proveedor", "f_det_proveedor", "f_tab_proveedor",
                "f_top_ente", "f_serie_ente", "f_det_ente", "f_tab_ente", "red", "t_atip", "t_cob"))
      chk(paste(modo, o), output[[o]])
  }
  session$setInputs(red_foco = "p:R/080115970019"); chk("red con foco", output$red)
  session$setInputs(atipicos = TRUE, tipo = "Licitación Pública"); chk("atípicos + tipo", output$p_serie)
  cat(sprintf("probar_app: %d OK, %d con error\n", ok, mal))
})
