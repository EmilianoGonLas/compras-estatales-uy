# 02 — Codigueras de ARCE: incisos y unidades ejecutoras (XML ISO-8859-1)
suppressPackageStartupMessages({library(xml2); library(dplyr); library(readr)})
base <- "http://www.comprasestatales.gub.uy/comprasenlinea/jboss/"
leer <- function(u, nodo, attrs) {
  x <- read_xml(paste0(base, u), encoding = "ISO-8859-1")
  n <- xml_find_all(x, paste0("//", nodo))
  as_tibble(setNames(lapply(attrs, \(a) xml_attr(n, a)), attrs))
}
inc <- leer("reporteIncisos.do", "inciso", c("id-inciso", "nom-inciso")) |>
  rename(inciso_id = 1, inciso = 2)
ue <- leer("reporteUnidadesEjecutoras.do", "unidad-ejecutora",
           c("id-inciso", "id-ue", "nom-ue")) |>
  rename(inciso_id = 1, ue_id = 2, ue = 3) |>
  mutate(across(everything(), trimws))
dir.create("data", showWarnings = FALSE)
write_csv(inc, "data/codiguera_incisos.csv")
write_csv(ue,  "data/codiguera_ue.csv")
cat(nrow(inc), "incisos,", nrow(ue), "unidades ejecutoras\n")
