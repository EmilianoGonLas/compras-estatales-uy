# ============================================================
# Informes PDF (proveedor o ente público)
# Armados con ggplot2 + gridExtra sobre un dispositivo cairo_pdf: no necesitan
# LaTeX ni Chrome, así que corren igual en la PC y en shinyapps.io.
# ============================================================

AZUL <- "#1f4e79"; GRIS <- "#6b7280"

.corta <- function(x, n) ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "…"), x)

.titulo_grob <- function(titulo, sub) {
  grid::textGrob(paste0(paste(strwrap(titulo, 55), collapse = "\n"), "\n"),
    x = 0.02, hjust = 0, vjust = 1, y = 0.95,
    gp = grid::gpar(fontsize = 17, fontface = "bold", col = AZUL)) -> g1
  g2 <- grid::textGrob(sub, x = 0.02, hjust = 0, vjust = 0, y = 0.02,
                       gp = grid::gpar(fontsize = 8.5, col = GRIS))
  grid::grobTree(g1, g2)
}

.kpi_grob <- function(etiquetas, valores) {
  n <- length(valores)
  gs <- lapply(seq_len(n), function(i) {
    x <- (i - 0.5) / n
    grid::grobTree(
      grid::rectGrob(x = x, width = 0.95 / n, gp = grid::gpar(fill = "#eef3f8", col = NA)),
      grid::textGrob(valores[i], x = x, y = 0.62,
                     gp = grid::gpar(fontsize = 13, fontface = "bold", col = AZUL)),
      grid::textGrob(etiquetas[i], x = x, y = 0.25,
                     gp = grid::gpar(fontsize = 7.5, col = GRIS)))
  })
  do.call(grid::grobTree, gs)
}

.pie <- function(pag, total) grid::textGrob(
  sprintf("Fuente: ARCE – Compras Estatales (OCDS), vía catalogodatos.gub.uy · Página %d de %d", pag, total),
  gp = grid::gpar(fontsize = 6.5, col = GRIS))

# tipo: "proveedor" | "ente"; id: proveedor_id o comprador_id
informe_pdf <- function(tipo, id, moneda, anios, file, atipicos = FALSE, tipo_proc = "") {
  mon <- moneda; a0 <- anios[1]; a1 <- anios[2]
  P <- pares[moneda == mon & anio >= a0 & anio <= a1]
  if (!atipicos) P <- P[atipico == FALSE]
  if (nzchar(tipo_proc)) P <- P[tipo == tipo_proc]
  es_prov <- tipo == "proveedor"
  S <- if (es_prov) P[proveedor_id == id] else P[comprador_id == id]
  nombre <- if (es_prov) pares[proveedor_id == id][1, proveedor] else pares[comprador_id == id][1, comprador]
  contra  <- if (es_prov) "comprador" else "proveedor"
  contra_lbl <- if (es_prov) "Entes públicos compradores" else "Proveedores adjudicados"
  if (nrow(S) == 0) stop("Sin adjudicaciones en ", mon, " para ese período.")

  tot <- sum(S$monto)
  por_contra <- S[, .(monto = sum(monto), n = sum(n)), by = c(contra)][order(-monto)]
  setnames(por_contra, contra, "contra")
  conc <- concentracion(por_contra$monto)
  serie <- S[, .(monto = sum(monto), n = sum(n)), by = anio][order(anio)]
  tipos <- S[, .(monto = sum(monto), n = sum(n)), by = tipo][order(-monto)]

  sub <- sprintf("%s · %d–%d · montos en %s · generado el %s",
                 if (es_prov) "Informe de proveedor" else "Informe de ente público",
                 a0, a1, mon, format(Sys.Date(), "%d/%m/%Y"))
  kpis <- .kpi_grob(
    c("Monto adjudicado", "Adjudicaciones", paste0(if (es_prov) "Entes" else "Proveedores", " distintos"),
      if (es_prov) "Peso del ente principal" else "Peso del proveedor principal"),
    c(fmt_monto(tot, mon), fmt_n(sum(S$n)), fmt_n(nrow(por_contra)), fmt_pct(conc$top1)))

  tema <- theme_minimal(base_size = 9) +
    theme(plot.title = element_text(face = "bold", colour = AZUL, size = 10),
          panel.grid.minor = element_blank(), panel.grid.major.y = element_blank())
  g_serie <- ggplot(serie, aes(factor(anio), monto)) +
    geom_col(fill = AZUL, width = 0.7) +
    scale_y_continuous(labels = \(x) fmt_n(x / 1e6, 1)) +
    labs(title = paste0("Monto adjudicado por año (millones de ", mon, ")"), x = NULL, y = NULL) +
    tema + theme(panel.grid.major.y = element_line(colour = "#e5e7eb"),
                 axis.text.x = element_text(angle = if (nrow(serie) > 12) 90 else 0, vjust = 0.5))
  top <- head(por_contra, 10)
  top$etq <- .corta(top$contra, 42)
  top$etq <- factor(top$etq, levels = rev(unique(top$etq)))
  g_top <- ggplot(top, aes(etq, monto)) +
    geom_col(fill = AZUL, width = 0.7) +
    geom_text(aes(label = fmt_pct(monto / tot, 0)), hjust = -0.15, size = 2.8, colour = GRIS) +
    coord_flip() + scale_y_continuous(expand = expansion(mult = c(0, 0.18)), labels = NULL) +
    labs(title = paste0(contra_lbl, " (top 10, % del total)"), x = NULL, y = NULL) + tema
  tp <- head(tipos, 8); tp$etq <- factor(.corta(tp$tipo, 38), levels = rev(.corta(tp$tipo, 38)))
  g_tipo <- ggplot(tp, aes(etq, monto)) + geom_col(fill = "#4f81b0", width = 0.7) +
    geom_text(aes(label = fmt_pct(monto / tot, 0)), hjust = -0.15, size = 2.8, colour = GRIS) +
    coord_flip() + scale_y_continuous(expand = expansion(mult = c(0, 0.18)), labels = NULL) +
    labs(title = "Tipo de procedimiento (% del monto)", x = NULL, y = NULL) + tema

  txt_conc <- sprintf(
    "Concentración: el %s concentra el %s del monto; los 5 mayores, el %s; los 10 mayores, el %s (HHI %s sobre 10.000).",
    if (es_prov) "ente principal" else "proveedor principal",
    fmt_pct(conc$top1), fmt_pct(conc$top5), fmt_pct(conc$top10), fmt_n(conc$hhi))
  g_conc <- grid::textGrob(paste(strwrap(txt_conc, 105), collapse = "\n"),
                           x = 0.02, hjust = 0, gp = grid::gpar(fontsize = 8.5))

  # ---- detalle: las mayores adjudicaciones (lectura a demanda del parquet) ----
  d <- adj_ds |> filter(estado == "active", moneda == mon, anio >= a0, anio <= a1)
  d <- if (es_prov) d |> filter(proveedor_id == id) else d |> filter(comprador_id == id)
  if (!atipicos) d <- d |> filter(!atipico)
  if (nzchar(tipo_proc)) d <- d |> filter(tipo == tipo_proc)
  d <- d |> select(fecha, comprador, proveedor, objeto, tipo, titulo, monto) |> collect()
  d <- d |> arrange(desc(monto)) |> head(32)
  tab <- data.frame(
    Fecha = format(d$fecha, "%d/%m/%Y"),
    Contraparte = .corta(if (es_prov) d$comprador else d$proveedor, 30),
    Objeto = .corta(coalesce(d$objeto, ""), 38),
    Procedimiento = .corta(coalesce(d$titulo, d$tipo, ""), 28),
    Monto = fmt_n(d$monto), check.names = FALSE)
  tt <- ttheme_minimal(base_size = 6.8,
    core = list(fg_params = list(hjust = 0, x = 0.02)),
    colhead = list(fg_params = list(hjust = 0, x = 0.02, fontface = "bold", col = AZUL)))
  g_tab <- tableGrob(tab, rows = NULL, theme = tt)

  nota <- paste(strwrap(paste(
    "Notas metodológicas. Los montos son la suma de cantidad × precio unitario de los ítems de cada",
    "adjudicación activa publicada por ARCE; el OCDS no publica un total por adjudicación, por lo que",
    "los ítems sin precio no suman. Las monedas no se convierten ni se suman entre sí: este informe",
    "cubre únicamente", mon, ". Los nombres se normalizan al más reciente de cada identificador",
    "(RUPE / unidad ejecutora).", if (atipicos) "Incluye montos atípicos." else
    "Excluye adjudicaciones con montos atípicos (posibles errores de carga; ver la sección Calidad de datos de la app).",
    if (nzchar(tipo_proc)) paste0("Sólo procedimientos de tipo «", tipo_proc, "». ") else "",
    "Lo adjudicado no equivale a lo efectivamente pagado ni ejecutado.",
    "Una alta concentración describe la estructura de las adjudicaciones; no implica irregularidad."), 110),
    collapse = "\n")
  g_nota <- grid::textGrob(nota, x = 0.02, hjust = 0, vjust = 1, y = 0.98,
                           gp = grid::gpar(fontsize = 7.5, col = GRIS))

  cairo_pdf(file, width = 8.27, height = 11.69, onefile = TRUE)
  on.exit(dev.off(), add = TRUE)
  TOT <- 2
  grid.arrange(.titulo_grob(nombre, sub), kpis, g_serie, g_top, g_tipo, g_conc, .pie(1, TOT),
    layout_matrix = rbind(1, 2, 3, 4, 5, 6, 7),
    heights = c(1.1, 0.8, 2.6, 2.7, 2.2, 0.5, 0.25))
  grid.arrange(
    grid::textGrob("Mayores adjudicaciones del período", x = 0.02, hjust = 0,
                   gp = grid::gpar(fontsize = 11, fontface = "bold", col = AZUL)),
    g_tab, g_nota, .pie(2, TOT),
    heights = c(0.4, 6.6, 1.2, 0.2))
  invisible(file)
}
