# ============================================================
# Shiny App — Compras estatales de Uruguay: proveedores y entes públicos
# ============================================================
source("global.R", encoding = "UTF-8")

kpi <- function(titulo, valor, sub = NULL) {
  div(class = "kpi", div(class = "kpi-v", valor), div(class = "kpi-t", titulo),
      if (!is.null(sub)) div(class = "kpi-s", sub))
}

# Tipografía empaquetada en www/fonts: evita que el servidor la baje de Google al arrancar.
fuente_local <- htmltools::htmlDependency("Source_Sans_3_local", "0.4.10", src = c(file = "www/fonts"),
                                          stylesheet = "font.css")

ui <- page_navbar(
  id = "nav", fillable = FALSE,
  title = "Compras estatales · Uruguay",
  theme = bs_theme(version = 5, primary = "#1f4e79",
                   base_font = "'Source Sans 3', system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
                   heading_font = "'Source Sans 3', system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"),
  header = tagList(
    # Si el proxy de Connect Cloud falla con 503 en el CSS/JS (pasa en los arranques en frío), la página queda
    # sin estilo y sin datos. Este bloque no depende de ningún archivo estático: avisa y recarga sola (máx. 3 veces).
    div(id = "cargando", style = "padding:8px 14px;font:14px system-ui,sans-serif;background:#0b1220;color:#9fb4d8;text-align:center",
        "Cargando la app… la primera visita tarda unos segundos; si hace falta, se reintenta sola."),
    tags$script(HTML("
      (function () {
        var K = 'compras_reintentos', n = +(sessionStorage.getItem(K) || 0), t0 = Date.now();
        function listo() {
          var nav = document.querySelector('.navbar'), k = document.getElementById('k1');
          var css = nav && getComputedStyle(nav).display === 'flex';
          var js = window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected && Shiny.shinyapp.isConnected();
          return css && js && k && k.innerText.trim().length > 0;
        }
        function revisar() {
          if (listo()) { sessionStorage.removeItem(K); var c = document.getElementById('cargando'); if (c) c.remove(); return; }
          if (Date.now() - t0 > 14000 && n < 3) { sessionStorage.setItem(K, n + 1); location.reload(); return; }
          setTimeout(revisar, 1000);
        }
        window.addEventListener('load', function () { setTimeout(revisar, 2000); });
      })();")),
    tags$head(fuente_local, tags$style(HTML("
    :root{--acento:#1f4e79;--acento2:#e07b39}
    [data-bs-theme=dark]{--acento:#7cb7f5;--acento2:#f0a05a}
    .kpi{background:var(--bs-tertiary-bg);border-radius:8px;padding:12px 14px;margin-bottom:10px}
    .kpi-v{font-size:1.5rem;font-weight:700;color:var(--acento);line-height:1.1}
    .kpi-t{font-size:.8rem;color:var(--bs-secondary-color)}.kpi-s{font-size:.75rem;color:var(--bs-secondary-color);opacity:.8}
    .nota{font-size:.82rem;color:var(--bs-secondary-color)}
    @keyframes aparece{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
    .info-nodo{animation:aparece .35s ease-out;border-left:4px solid var(--acento);background:var(--bs-tertiary-bg);border-radius:8px;padding:12px 14px;margin-top:10px}
    .info-nodo.prov{border-left-color:var(--acento2)}
    .info-nodo h5{font-size:1rem;margin-bottom:6px}
    .leyenda-red{font-size:.8rem;color:var(--bs-secondary-color);margin-top:8px}
    [data-bs-theme=dark] .btn-outline-primary{--bs-btn-color:var(--acento);--bs-btn-border-color:var(--acento);--bs-btn-hover-bg:var(--acento);--bs-btn-hover-border-color:var(--acento);--bs-btn-hover-color:#0b1220;--bs-btn-active-bg:var(--acento);--bs-btn-active-color:#0b1220}
    [data-bs-theme=dark] .btn-primary{--bs-btn-bg:#2f6fb0;--bs-btn-border-color:#2f6fb0;--bs-btn-hover-bg:#3b82c4;--bs-btn-hover-border-color:#3b82c4}
    bslib-input-dark-mode{margin-left:.5rem}
    .bh{display:grid;grid-template-columns:minmax(90px,36%) 1fr minmax(84px,auto);gap:10px;align-items:center;padding:3px 0;font-size:.85rem}
    .bh:hover{background:var(--bs-tertiary-bg);border-radius:6px}
    .bh-l{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    .bh-b{height:14px;background:var(--bs-tertiary-bg);border-radius:7px;overflow:hidden}
    .bh-b span{display:block;height:100%;border-radius:7px;min-width:2px}
    .bh-v{text-align:right;color:var(--bs-secondary-color);font-size:.78rem;white-space:nowrap}
    .bv{display:flex;align-items:flex-end;gap:5px;height:250px;padding-top:6px}
    .bv-c{flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:stretch;height:100%;min-width:0}
    .bv-c:hover .bv-b{opacity:.8}
    .bv-b{border-radius:5px 5px 0 0;min-height:2px;transition:opacity .15s}
    .bv-v{text-align:center;font-size:.72rem;color:var(--bs-secondary-color);margin-bottom:3px;white-space:nowrap}
    .bv-x{text-align:center;font-size:.72rem;color:var(--bs-secondary-color);margin-top:4px}
    .bv-muchas .bv-x{font-size:.62rem}
    .bv-muchas .bv-c:nth-child(even) .bv-x{visibility:hidden}")),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"))),
  sidebar = sidebar(width = 270,
    selectInput("moneda", "Moneda",
                choices = setNames(monedas, ifelse(monedas %in% names(etiqueta_moneda),
                                                   etiqueta_moneda[monedas], monedas))),
    sliderInput("anios", "Años", min = anios[1], max = anios[2], value = c(max(anios[1], anios[2] - 4), anios[2]),
                step = 1, sep = ""),
    selectInput("tipo", "Procedimiento", choices = c("Todos" = ""), selected = ""),
    checkboxInput("atipicos", "Incluir montos atípicos", FALSE),
    hr(),
    p(class = "nota", "Los montos suman cantidad × precio unitario de los ítems adjudicados. ",
      "Las monedas no se convierten entre sí. Adjudicado ≠ pagado."),
    p(class = "nota", paste("Datos hasta", format(ULTIMA_FECHA, "%d/%m/%Y")))
  ),

  nav_panel("Panorama",
    layout_columns(col_widths = c(3, 3, 3, 3), uiOutput("k1"), uiOutput("k2"), uiOutput("k3"), uiOutput("k4")),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Monto adjudicado por año", span(class = "nota ms-2", "(pasá el mouse por una barra)")), uiOutput("p_serie")),
      card(card_header("Mayores proveedores del período"), uiOutput("p_top"))),
    card(card_header("Procedimientos"), uiOutput("p_tipos"))),

  nav_panel("Proveedores",
    card(fill = FALSE, card_header("Ranking de proveedores — hacé clic en una fila para abrir su ficha"), DTOutput("t_prov")),
    selectizeInput("prov", "O buscá un proveedor por nombre o RUT", choices = NULL, width = "100%"),
    uiOutput("ficha_prov")),

  nav_panel("Entes públicos",
    card(fill = FALSE, card_header("Ranking de entes compradores — hacé clic en una fila para abrir su ficha"), DTOutput("t_comp")),
    selectizeInput("comp", "O buscá un ente (unidad ejecutora)", choices = NULL, width = "100%"),
    uiOutput("ficha_comp")),

  nav_panel("Vínculos",
    layout_columns(col_widths = c(3, 9),
      div(
        selectizeInput("red_foco", "Partir de un proveedor o un ente", choices = NULL, width = "100%",
                       options = list(placeholder = "Escribí un nombre o RUT… (vacío = panorama general)")),
        sliderInput("n_red", "Vínculos iniciales", 5, 60, 20, step = 5),
        uiOutput("red_info"),
        div(class = "leyenda-red", HTML(paste0(
          "<b>Cómo usarla</b><br>",
          "• <b>Un clic</b> en un nodo: ver su detalle.<br>",
          "• <b>Doble clic</b>: expande sus vínculos (salen del nodo).<br>",
          "• Pasá el mouse por una línea para ver el monto.<br>",
          "• Arrastrá los nodos; rueda para zoom.<br>",
          "<span style='color:var(--acento2)'>●</span> proveedor &nbsp; <span style='color:var(--acento)'>■</span> ente público. ",
          "El tamaño es el monto total del período; el grosor de la línea, el monto del vínculo.")))),
      card(visNetworkOutput("red", height = 680)))),

  nav_panel("Red 3D",
    tags$iframe(src = "red3d.html", title = "Red 3D de compras estatales", allowfullscreen = NA,
                style = "width:100%;height:calc(100vh - 70px);min-height:560px;border:0;border-radius:10px;background:#04060d"),
    p(class = "nota", "Red de redes en 3D: incisos → entes → proveedores. Usa sus propios controles ",
      "(no responde a los filtros del panel lateral). ",
      tags$a(href = "red3d.html", target = "_blank", "Abrir a pantalla completa"))),

  nav_panel("Calidad de datos",
    card(card_body(
      p("La fuente trae montos que no pueden ser reales, mezclados con megacontratos que sí lo son. ",
        "Estas adjudicaciones superan un umbral de plausibilidad (UYU 5.000 M · USD 200 M · EUR 150 M · UYI 1.000 M) y ",
        strong("se excluyen por defecto"), " de todos los totales. Marcá «Incluir montos atípicos» para verlas incorporadas. ",
        "No se corrigen ni se descartan: revisalas una por una."),
      DTOutput("t_atip"))),
    card(card_header("Adjudicaciones y proveedores identificados por año"), DTOutput("t_cob"))),

  nav_panel("Acerca de",
    card(card_body(HTML(paste(readLines("docs/acerca.html", encoding = "UTF-8"), collapse = "\n"))))),

  nav_spacer(),
  nav_item(input_dark_mode(id = "modo", mode = "dark"))
)

server <- function(input, output, session) {

  observe({
    ts <- TIPOS
    updateSelectInput(session, "tipo", choices = c("Todos" = "", setNames(ts, ts)))
  })
  # Con server = TRUE las opciones hay que reenviarlas cada vez que cambia `selected`.
  sel_prov <- function(id = character(0)) updateSelectizeInput(session, "prov", choices = prov_ch, selected = id, server = TRUE)
  sel_comp <- function(id = character(0)) updateSelectizeInput(session, "comp", choices = comp_ch, selected = id, server = TRUE)
  sel_prov(); sel_comp()

  # Subconjunto vigente según los filtros globales
  P <- reactive({
    req(input$moneda, input$anios)   # antes de que lleguen las entradas no se dibuja nada (en vez de "NA")
    d <- pares[moneda == input$moneda & anio >= input$anios[1] & anio <= input$anios[2]]
    if (nzchar(input$tipo)) d <- d[tipo == input$tipo]
    if (!isTRUE(input$atipicos)) d <- d[atipico == FALSE]
    d
  })
  mon <- reactive(input$moneda)

  # Modo oscuro por defecto: hasta que el cliente informa, `input$modo` es NULL.
  oscuro <- reactive(!identical(input$modo, "light"))

  # ---------------- Panorama ----------------
  output$k1 <- renderUI(kpi("Monto adjudicado", fmt_monto(sum(P()$monto), mon())))
  output$k2 <- renderUI(kpi("Adjudicaciones", fmt_n(sum(P()$n))))
  output$k3 <- renderUI(kpi("Proveedores distintos", fmt_n(uniqueN(P()$proveedor_id))))
  output$k4 <- renderUI({
    pv <- P()[, .(m = sum(monto)), by = proveedor_id]
    kpi("Peso de los 10 mayores proveedores", fmt_pct(concentracion(pv$m)$top10),
        paste(fmt_n(uniqueN(P()$comprador_id)), "entes compradores"))
  })
  output$p_serie <- renderUI({
    d <- P()[, .(monto = sum(monto)), by = anio][order(anio)]
    barras_v(d$anio, d$monto)
  })
  output$p_top <- renderUI({
    d <- P()[, .(monto = sum(monto)), by = .(proveedor_id, proveedor)][order(-monto)][1:12]
    barras_h(d$proveedor, d$monto)
  })
  output$p_tipos <- renderUI({
    d <- P()[, .(monto = sum(monto)), by = tipo][order(-monto)][1:10]
    barras_h(d$tipo, d$monto, col = "var(--acento2)")
  })

  # ---------------- Rankings ----------------
  tabla_ranking <- function(d, id, nom, contra, contra_lbl) {
    # Dos pasadas: primero el par (entidad, contraparte), después una fila por entidad.
    pc <- d[, .(m = sum(monto), n = sum(n)), by = c(id, nom, contra)]
    setorderv(pc, c(id, "m"), c(1L, -1L))
    r <- pc[, .(Adjudicaciones = sum(n), Monto = sum(m), N = .N,
                Principal = get(contra)[1], Peso = m[1] / sum(m)), by = c(id, nom)][order(-Monto)]
    setnames(r, c(id, nom, "N", "Principal"),
             c("id", "Nombre", paste0(contra_lbl, "s"), paste0(contra_lbl, " principal")))
    r
  }
  rank_prov <- reactive(tabla_ranking(P(), "proveedor_id", "proveedor", "comprador", "Ente"))
  rank_comp <- reactive(tabla_ranking(P(), "comprador_id", "comprador", "proveedor", "Proveedor"))

  mostrar_rank <- function(r) {
    datatable(r[, !"id"], selection = "single", rownames = FALSE, options = list(
      pageLength = 10, dom = "frtip", language = dt_es, autoWidth = FALSE,
      columnDefs = list(list(targets = c(1, 2), className = "dt-right"))), class = "compact stripe") |>
      formatCurrency("Monto", currency = "", mark = ".", dec.mark = ",", digits = 0) |>
      formatPercentage("Peso", 0)
  }
  output$t_prov <- renderDT(mostrar_rank(rank_prov()))
  output$t_comp <- renderDT(mostrar_rank(rank_comp()))
  observeEvent(input$t_prov_rows_selected, {
    sel_prov(rank_prov()$id[input$t_prov_rows_selected])
  })
  observeEvent(input$t_comp_rows_selected, {
    sel_comp(rank_comp()$id[input$t_comp_rows_selected])
  })

  # ---------------- Fichas ----------------
  ficha <- function(tipo, id) {
    es_prov <- tipo == "proveedor"
    d <- if (es_prov) P()[proveedor_id == id] else P()[comprador_id == id]
    if (!nrow(d)) return(card(card_body("Sin adjudicaciones con estos filtros.")))
    nombre <- if (es_prov) d$proveedor[1] else d$comprador[1]
    contra <- if (es_prov) "comprador" else "proveedor"
    cc <- d[, .(monto = sum(monto), n = sum(n)), by = c(contra)][order(-monto)]
    conc <- concentracion(cc$monto)
    ns <- if (es_prov) "dl_prov" else "dl_comp"
    tagList(
      h4(nombre), if (!es_prov) p(class = "nota", d$inciso[1]),
      layout_columns(col_widths = c(3, 3, 3, 3),
        kpi("Monto", fmt_monto(sum(d$monto), mon())), kpi("Adjudicaciones", fmt_n(sum(d$n))),
        kpi(if (es_prov) "Entes" else "Proveedores", fmt_n(nrow(cc))),
        kpi("Peso del principal", fmt_pct(conc$top1))),
      div(class = "mb-2",
        downloadButton(ns, "Descargar informe PDF", class = "btn-primary btn-sm"),
        actionButton(paste0("go_red_", tipo), "Ver su red de vínculos", icon = icon("diagram-project"), class = "btn-outline-primary btn-sm")),
      card(card_header(paste0(if (es_prov) "Entes" else "Proveedores", " vinculados")),
           uiOutput(paste0("f_top_", tipo))),
      card(card_header(paste0("Todos los vínculos — clic en una fila para abrir ", if (es_prov) "el ente" else "al proveedor")),
           DTOutput(paste0("f_tab_", tipo))),
      card(card_header("Evolución anual"), uiOutput(paste0("f_serie_", tipo))),
      card(card_header("Mayores adjudicaciones"), DTOutput(paste0("f_det_", tipo))))
  }
  output$ficha_prov <- renderUI(if (nzchar(input$prov %||% "")) ficha("proveedor", input$prov))
  output$ficha_comp <- renderUI(if (nzchar(input$comp %||% "")) ficha("ente", input$comp))

  subset_ficha <- function(tipo) {
    if (tipo == "proveedor") P()[proveedor_id == input$prov] else P()[comprador_id == input$comp]
  }
  for (tipo in c("proveedor", "ente")) local({
    tipo <- tipo
    contra <- if (tipo == "proveedor") "comprador" else "proveedor"
    output[[paste0("f_top_", tipo)]] <- renderUI({
      d <- subset_ficha(tipo)[, .(monto = sum(monto)), by = c(contra)][order(-monto)][1:12]
      d <- d[!is.na(monto)]
      barras_h(d[[contra]], d$monto)
    })
    output[[paste0("f_serie_", tipo)]] <- renderUI({
      d <- subset_ficha(tipo)[, .(monto = sum(monto)), by = anio][order(anio)]
      barras_v(d$anio, d$monto, col = "var(--acento2)")
    })
    output[[paste0("f_det_", tipo)]] <- renderDT({
      id <- if (tipo == "proveedor") input$prov else input$comp
      m <- mon(); a0 <- input$anios[1]; a1 <- input$anios[2]
      d <- adj_ds() |> filter(estado == "active", moneda == m, anio >= a0, anio <= a1)
      d <- if (tipo == "proveedor") d |> filter(proveedor_id == id) else d |> filter(comprador_id == id)
      if (!isTRUE(input$atipicos)) d <- d |> filter(!atipico)
      if (nzchar(input$tipo)) { tp <- input$tipo; d <- d |> filter(tipo == tp) }
      d <- d |> select(fecha, comprador, proveedor, objeto, titulo, monto) |> collect() |>
        arrange(desc(monto)) |> head(200)
      if (tipo == "proveedor") d$proveedor <- NULL else d$comprador <- NULL
      names(d) <- c("Fecha", if (tipo == "proveedor") "Ente" else "Proveedor", "Objeto", "Procedimiento", "Monto")
      datatable(d, rownames = FALSE, class = "compact stripe",
                options = list(pageLength = 8, dom = "tp", scrollX = TRUE, language = dt_es)) |>
        formatCurrency("Monto", currency = "", mark = ".", dec.mark = ",", digits = 0)
    })
  })

  # ---------------- Informes PDF ----------------
  descarga <- function(tipo, id_fn) downloadHandler(
    filename = function() sprintf("informe_%s_%s.pdf", tipo, gsub("[^0-9A-Za-z]+", "_", id_fn())),
    content = function(file) {
      withProgress(message = "Armando el informe…", value = 0.5,
        informe_pdf(tipo, id_fn(), mon(), input$anios, file, isTRUE(input$atipicos), input$tipo))
    })
  output$dl_prov <- descarga("proveedor", reactive(input$prov))
  output$dl_comp <- descarga("ente", reactive(input$comp))

  # ---------------- Calidad de datos ----------------
  output$t_atip <- renderDT({
    d <- adj_ds() |> filter(atipico) |> select(anio, comprador, proveedor, objeto, moneda, monto) |>
      collect() |> arrange(desc(monto))
    names(d) <- c("Año", "Ente", "Proveedor", "Objeto", "Moneda", "Monto")
    datatable(d, rownames = FALSE, class = "compact stripe", options = list(pageLength = 10, scrollX = TRUE, language = dt_es)) |>
      formatCurrency("Monto", currency = "", mark = ".", dec.mark = ",", digits = 0)
  })
  output$t_cob <- renderDT({
    d <- adj_ds() |> filter(estado == "active", anio >= 2002) |>
      group_by(anio) |> summarise(n = n(), sin_prov = sum(is.na(proveedor_id)), sin_tipo = sum(is.na(tipo))) |>
      collect() |> arrange(anio)
    d <- data.frame(Año = d$anio, Adjudicaciones = d$n,
                    `Sin proveedor` = fmt_pct(d$sin_prov / d$n), `Sin tipo de procedimiento` = fmt_pct(d$sin_tipo / d$n),
                    check.names = FALSE)
    datatable(d, rownames = FALSE, class = "compact stripe", options = list(pageLength = 12, dom = "tp", language = dt_es))
  })

  # ---------------- Red de vínculos ----------------
  updateSelectizeInput(session, "red_foco", choices = foco_ch, selected = character(0), server = TRUE)
  ir_a_red <- function(nodo) {
    nav_select("nav", "Vínculos")
    updateSelectizeInput(session, "red_foco", choices = foco_ch, selected = nodo, server = TRUE)
  }

  # Totales por nodo en el período vigente (tamaño de los nodos)
  # Dos pasadas (par proveedor-ente -> total por nodo). Un uniqueN() dentro de un by= con 17.000 grupos
  # reparte memoria por hilo y llevaba el proceso de 310 a 1.260 MB: shinyapps.io (1 GB) lo mataba por OOM.
  pares_pe <- reactive(P()[, .(monto = sum(monto), n = sum(n)), by = .(proveedor_id, proveedor, comprador_id, comprador)])
  tot_prov <- reactive(pares_pe()[, .(monto = sum(monto), n = sum(n), k = .N), by = .(id = proveedor_id, nombre = proveedor)])
  tot_comp <- reactive(pares_pe()[, .(monto = sum(monto), n = sum(n), k = .N), by = .(id = comprador_id, nombre = comprador)])

  nodo_dt <- function(ids, es_prov) {
    t <- if (es_prov) tot_prov() else tot_comp()
    x <- t[id %in% ids]
    x[, .(id = paste0(if (es_prov) "p:" else "e:", id),
          label = ifelse(nchar(nombre) > 26, paste0(substr(nombre, 1, 25), "…"), nombre),
          title = paste0("<b>", nombre, "</b><br>", fmt_monto(monto, mon()), " · ", fmt_n(n), " adjudicaciones"),
          group = if (es_prov) "Proveedor" else "Ente público",
          shape = if (es_prov) "dot" else "square", value = monto)]
  }
  # Vecinos de un nodo: sus k mayores contrapartes (aristas con monto)
  vecinos <- function(nodo, k) {
    d <- P(); es_prov <- startsWith(nodo, "p:"); id <- substring(nodo, 3)
    if (es_prov) {
      x <- d[proveedor_id == id, .(monto = sum(monto), n = sum(n)), by = .(oid = comprador_id)][order(-monto)][seq_len(min(k, .N))]
      x[, `:=`(from = nodo, to = paste0("e:", oid))]
    } else {
      x <- d[comprador_id == id, .(monto = sum(monto), n = sum(n)), by = .(oid = proveedor_id)][order(-monto)][seq_len(min(k, .N))]
      x[, `:=`(from = paste0("p:", oid), to = nodo)]
    }
    x[, `:=`(otro = !es_prov)]
    list(edges = x, otros = x$oid, otro_es_prov = !es_prov)
  }
  aristas_dt <- function(e) e[, .(id = paste(from, to), from = from, to = to, value = monto,
    title = paste0(fmt_monto(monto, mon()), " · ", fmt_n(n), " adjudicaciones"))]

  ids_red <- reactiveVal(character(0))

  grafo_inicial <- reactive({
    foco <- input$red_foco %||% ""; k <- input$n_red
    d <- P()
    if (!nzchar(foco)) {   # panorama: los mayores pares
      pp <- d[, .(monto = sum(monto), n = sum(n)), by = .(proveedor_id, comprador_id)][order(-monto)][seq_len(min(k * 2, .N))]
      e <- pp[, .(from = paste0("p:", proveedor_id), to = paste0("e:", comprador_id), monto, n)]
      pv <- nodo_dt(unique(pp$proveedor_id), TRUE); ce <- nodo_dt(unique(pp$comprador_id), FALSE)
      return(list(nodes = rbind(pv, ce), edges = aristas_dt(e), centro = NULL))
    }
    v <- vecinos(foco, k)
    centro <- nodo_dt(substring(foco, 3), startsWith(foco, "p:"))
    if (!nrow(centro)) return(list(nodes = centro, edges = NULL, centro = foco))
    otros <- nodo_dt(v$otros, v$otro_es_prov)
    otros[, value := v$edges$monto[match(substring(id, 3), v$edges$oid)]]   # tamaño = peso del vínculo
    centro[, `:=`(borderWidth = 4, color.border = "#facc15", font.size = 18)]
    list(nodes = rbind(centro, otros, fill = TRUE), edges = aristas_dt(v$edges), centro = foco)
  })

  output$red <- renderVisNetwork({
    g <- grafo_inicial()
    validate(need(nrow(g$nodes) > 0, "Sin adjudicaciones con estos filtros para ese nodo."))
    isolate(ids_red(g$nodes$id))
    dk <- oscuro()
    visNetwork(g$nodes, g$edges) |>
      visGroups(groupname = "Proveedor", color = list(background = "#e07b39", border = "#b45309", highlight = "#f59e0b")) |>
      visGroups(groupname = "Ente público", color = list(background = if (dk) "#3b82f6" else "#1f4e79", border = if (dk) "#93c5fd" else "#12304d", highlight = "#60a5fa")) |>
      visNodes(scaling = list(min = 10, max = 48),
               font = list(size = 13, face = "Source Sans 3", color = if (dk) "#e5e7eb" else "#343434", strokeWidth = if (dk) 3 else 0, strokeColor = "#0b1220"),
               shadow = list(enabled = TRUE, size = 6, x = 1, y = 2)) |>
      visEdges(scaling = list(min = 1, max = 12), color = list(color = if (dk) "#475569" else "#cbd5e1", highlight = if (dk) "#7cb7f5" else "#1f4e79", hover = if (dk) "#7cb7f5" else "#1f4e79"),
               smooth = list(enabled = TRUE, type = "continuous"), arrows = list(to = list(enabled = TRUE, scaleFactor = 0.4))) |>
      visOptions(highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE, algorithm = "hierarchical")) |>
      visInteraction(hover = TRUE, tooltipDelay = 80, navigationButtons = TRUE, zoomSpeed = 0.6) |>
      visPhysics(solver = "forceAtlas2Based", stabilization = FALSE,
                 forceAtlas2Based = list(gravitationalConstant = -70, springLength = 120, springConstant = 0.06, damping = 0.5),
                 minVelocity = 0.6) |>
      visLegend(useGroups = TRUE, position = "right", width = 0.12) |>
      visEvents(
        selectNode = "function(p){Shiny.setInputValue('red_sel', p.nodes[0], {priority:'event'});}",
        deselectNode = "function(p){Shiny.setInputValue('red_sel', null, {priority:'event'});}",
        doubleClick = "function(p){ if(p.nodes.length){ var id=p.nodes[0]; var pos=this.getPositions([id])[id]; Shiny.setInputValue('red_dbl', {id:id, x:pos.x, y:pos.y, t:Date.now()}, {priority:'event'}); } }",
        stabilized = "function(){ if(!this._ajustada){ this._ajustada=true; this.fit({animation:{duration:900, easingFunction:'easeInOutCubic'}}); } }")
  })

  # Expandir: los vecinos nacen en la posición del nodo y la física los reparte
  expandir <- function(nodo, x = NULL, y = NULL, k = 8) {
    v <- vecinos(nodo, k)
    nuevos <- setdiff(paste0(if (v$otro_es_prov) "p:" else "e:", v$otros), ids_red())
    px <- nodo_dt(v$otros, v$otro_es_prov)
    px <- px[id %in% nuevos]
    px[, value := v$edges$monto[match(substring(id, 3), v$edges$oid)]]
    if (!is.null(x) && nrow(px)) { px[, `:=`(x = x + runif(.N, -30, 30), y = y + runif(.N, -30, 30))] }
    proxy <- visNetworkProxy("red")
    if (nrow(px)) proxy |> visUpdateNodes(as.data.frame(px))
    proxy |> visUpdateEdges(as.data.frame(aristas_dt(v$edges))) |>
      visFocus(id = nodo, scale = 0.9, animation = list(duration = 800, easingFunction = "easeInOutQuad"))
    ids_red(union(ids_red(), nuevos))
    if (!length(nuevos)) showNotification("No hay más vínculos para mostrar con estos filtros.", type = "message", duration = 3)
  }
  observeEvent(input$red_dbl, expandir(input$red_dbl$id, input$red_dbl$x, input$red_dbl$y))
  observeEvent(input$red_expand, { req(input$red_sel); expandir(input$red_sel) })

  output$red_info <- renderUI({
    nodo <- input$red_sel
    if (is.null(nodo)) return(NULL)
    es_prov <- startsWith(nodo, "p:"); nid <- substring(nodo, 3)
    t <- if (es_prov) tot_prov() else tot_comp()
    r <- t[id == nid]
    if (!nrow(r)) return(NULL)
    top <- vecinos(nodo, 5)$edges
    nom_otros <- (if (es_prov) tot_comp() else tot_prov())[match(top$oid, id), nombre]
    div(class = paste("info-nodo", if (es_prov) "prov"), h5(r$nombre),
      p(class = "nota", if (es_prov) "Proveedor" else "Ente público"),
      p(strong(fmt_monto(r$monto, mon())), " · ", fmt_n(r$n), " adjudicaciones · ",
        fmt_n(r$k), if (es_prov) " entes" else " proveedores"),
      tags$small(class = "nota", "Mayores vínculos:"),
      tags$ol(style = "font-size:.8rem;padding-left:1.1rem;margin-bottom:8px",
              lapply(seq_len(nrow(top)), \(i) tags$li(substr(nom_otros[i], 1, 38), " — ", fmt_monto(top$monto[i], mon())))),
      actionButton("red_expand", "Expandir", class = "btn-sm btn-outline-primary"),
      actionButton("red_ficha", "Abrir ficha", class = "btn-sm btn-primary"))
  })
  observeEvent(input$red_ficha, {
    nodo <- req(input$red_sel); id <- substring(nodo, 3)
    if (startsWith(nodo, "p:")) { nav_select("nav", "Proveedores"); sel_prov(id) }
    else { nav_select("nav", "Entes públicos"); sel_comp(id) }
  })

  # Botones "Ver su red" y tabla de vínculos en las fichas
  observeEvent(input$go_red_proveedor, ir_a_red(paste0("p:", input$prov)))
  observeEvent(input$go_red_ente, ir_a_red(paste0("e:", input$comp)))

  vinc_tbl <- function(tipo) {
    d <- if (tipo == "proveedor") P()[proveedor_id == input$prov] else P()[comprador_id == input$comp]
    contra <- if (tipo == "proveedor") c("comprador_id", "comprador") else c("proveedor_id", "proveedor")
    x <- d[, .(Adjudicaciones = sum(n), Monto = sum(monto), desde = min(anio), hasta = max(anio)), by = contra]
    setnames(x, contra, c("id", "Nombre")); x[order(-Monto)][, `:=`(Peso = Monto / sum(Monto),
      Años = ifelse(desde == hasta, as.character(desde), paste0(desde, "–", hasta)))][, !c("desde", "hasta")]
  }
  for (tipo in c("proveedor", "ente")) local({
    tipo <- tipo
    output[[paste0("f_tab_", tipo)]] <- renderDT({
      x <- vinc_tbl(tipo)
      datatable(x[, !"id"], rownames = FALSE, selection = "single", class = "compact stripe",
                options = list(pageLength = 8, dom = "frtip", language = dt_es)) |>
        formatCurrency("Monto", currency = "", mark = ".", dec.mark = ",", digits = 0) |>
        formatPercentage("Peso", 1)
    })
    observeEvent(input[[paste0("f_tab_", tipo, "_rows_selected")]], {
      id <- vinc_tbl(tipo)$id[input[[paste0("f_tab_", tipo, "_rows_selected")]]]
      if (tipo == "proveedor") { nav_select("nav", "Entes públicos"); sel_comp(id) }
      else { nav_select("nav", "Proveedores"); sel_prov(id) }
    })
  })

}

shinyApp(ui, server)
