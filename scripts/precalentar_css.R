# Genera sass-cache/ con el CSS del tema ya compilado (ver global.R).
# Se levanta la app de verdad y se pide la página: así se cachea exactamente lo que Shiny compila
# al servirla (renderizar la ui a mano deja afuera variantes y no sirve).
# Correr desde la raíz tras cambiar el tema o actualizar bslib/sass, y volver a desplegar.
unlink("sass-cache", recursive = TRUE); dir.create("sass-cache")
puerto <- 4598
system2("Rscript", c("-e", shQuote(sprintf("shiny::runApp('.', port=%d, launch.browser=FALSE)", puerto))),
        wait = FALSE, stdout = FALSE, stderr = FALSE)
ok <- FALSE
for (i in 1:60) { Sys.sleep(1)
  ok <- tryCatch({ readLines(url(sprintf("http://127.0.0.1:%d/", puerto)), warn = FALSE); TRUE }, error = function(e) FALSE)
  if (ok) break }
system(sprintf("pkill -f 'port=%d'", puerto), ignore.stdout = TRUE, ignore.stderr = TRUE)
stopifnot(ok)
cat("sass-cache:", length(list.files("sass-cache", recursive = TRUE)), "archivos,",
    round(sum(file.size(list.files("sass-cache", full.names = TRUE, recursive = TRUE))) / 1e6, 2), "MB\n")
