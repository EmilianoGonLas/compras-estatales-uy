# Formato de montos y tablas en español rioplatense (miles con punto)
fmt_n <- function(x, d = 0) format(round(x, d), big.mark = ".", decimal.mark = ",",
                                   nsmall = d, scientific = FALSE, trim = TRUE)

fmt_monto <- function(x, moneda = "") {
  s <- ifelse(is.na(x), "s/d",
        ifelse(abs(x) >= 1e9, paste0(fmt_n(x / 1e9, 1), " mil millones"),
        ifelse(abs(x) >= 1e6, paste0(fmt_n(x / 1e6, 1), " millones"),
                              fmt_n(x))))
  trimws(paste(moneda, s))
}

fmt_pct <- function(x, d = 1) paste0(fmt_n(100 * x, d), " %")

# Etiquetas legibles para el selector de moneda
etiqueta_moneda <- c(UYU = "Pesos uruguayos (UYU)", USD = "Dólares (USD)",
                     EUR = "Euros (EUR)", UYI = "Unidades indexadas (UYI)")

# Concentración: participación acumulada de los k mayores y HHI (0–10.000)
concentracion <- function(montos) {
  montos <- montos[montos > 0]
  if (!length(montos)) return(list(top1 = NA, top5 = NA, top10 = NA, hhi = NA, n = 0))
  s <- sort(montos, decreasing = TRUE) / sum(montos)
  list(top1 = s[1], top5 = sum(head(s, 5)), top10 = sum(head(s, 10)),
       hhi = sum(s^2) * 10000, n = length(s))
}

# Traducción de DataTables inline (evita depender de un CDN para dibujar la tabla)
dt_es <- list(search = "Buscar:", zeroRecords = "Sin resultados", info = "_START_–_END_ de _TOTAL_",
              infoEmpty = "Sin datos", infoFiltered = "(de _MAX_)", lengthMenu = "Mostrar _MENU_",
              paginate = list(`first` = "«", previous = "‹", `next` = "›", last = "»"))
