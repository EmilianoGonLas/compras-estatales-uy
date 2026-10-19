# Gráficos livianos en HTML/CSS puro (sin plotly): la app arranca ~1,5 s más rápido y gasta ~100 MB
# menos de RAM, que es lo que importa con el apagado/encendido de la nube. Se adaptan solos al modo
# claro/oscuro (colores por variable CSS) y llevan tooltip nativo (atributo `title`).

# Barras horizontales: etiqueta | barra | valor. `tit` es el texto completo del tooltip.
barras_h <- function(etq, val, tit = etq, col = "var(--acento)", fmt = fmt_monto) {
  if (!length(val)) return(div(class = "nota", "Sin datos con estos filtros."))
  mx <- max(val, na.rm = TRUE); if (!is.finite(mx) || mx <= 0) mx <- 1
  div(class = "bh-wrap", lapply(seq_along(val), function(i)
    div(class = "bh", title = paste0(tit[i], " — ", fmt(val[i])),
        div(class = "bh-l", etq[i]),
        div(class = "bh-b", tags$span(style = sprintf("width:%.2f%%;background:%s", 100 * max(val[i], 0) / mx, col))),
        div(class = "bh-v", fmt(val[i])))))
}

# Barras verticales (serie anual): una columna por categoría; el valor se ve arriba si hay pocas barras.
barras_v <- function(x, val, col = "var(--acento)", fmt = fmt_monto) {
  if (!length(val)) return(div(class = "nota", "Sin datos con estos filtros."))
  mx <- max(val, na.rm = TRUE); if (!is.finite(mx) || mx <= 0) mx <- 1
  pocas <- length(val) <= 8
  div(class = paste("bv-wrap", if (!pocas) "bv-muchas"),
      div(class = "bv", lapply(seq_along(val), function(i)
        div(class = "bv-c", title = paste0(x[i], ": ", fmt(val[i])),
            if (pocas) div(class = "bv-v", fmt(val[i])),
            div(class = "bv-b", style = sprintf("height:%.2f%%;background:%s", 100 * max(val[i], 0) / mx, col)),
            div(class = "bv-x", x[i])))))
}
