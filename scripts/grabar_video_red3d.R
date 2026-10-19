# ============================================================
# Graba el video de la Red 3D (MP4 para LinkedIn) — determinista y fluido.
# La página con ?rec=1 usa un reloj virtual: se avanza 33,3 ms por cuadro, se captura y
# se arma con ffmpeg a 30 fps, sin depender de qué tan rápido renderice la máquina.
# Requiere: chromote, ffmpeg, y www/ servido en :8765  (cd www && python3 -m http.server 8765)
# Uso: Rscript scripts/grabar_video_red3d.R [salida.mp4]
# ============================================================
library(chromote); library(base64enc)
salida <- commandArgs(TRUE)[1]; if (is.na(salida)) salida <- "docs/linkedin/red3d.mp4"
tmp <- file.path(tempdir(), "frames"); dir.create(tmp, showWarnings = FALSE)
W <- 1280; H <- 720; ESC <- 1.5; FPS <- 30
chromote::set_chrome_args(c(chromote::default_chrome_args(), "--use-gl=angle", "--use-angle=swiftshader",
                            "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"))
b <- ChromoteSession$new(width = W, height = H)
b$Emulation$setDeviceMetricsOverride(width = W, height = H, deviceScaleFactor = ESC, mobile = FALSE)
ev <- function(js) { r <- b$Runtime$evaluate(js, returnByValue = TRUE)
  if (!is.null(r$exceptionDetails)) stop(r$exceptionDetails$exception$description); r$result$value }
k <- 0L
f <- function(n = 1) for (i in seq_len(n)) {            # un cuadro = un paso del reloj virtual + captura
  ev("__step(16.6667); __step(16.6667)"); r <- b$Page$captureScreenshot(format = "jpeg", quality = 93)
  k <<- k + 1L; writeBin(base64decode(r$data), file.path(tmp, sprintf("f%05d.jpg", k)))
  if (k %% 100 == 0) cat("cuadro", k, "\n") }
cap <- function(html, seg) ev(sprintf("__cap(%s, %d)", jsonlite::toJSON(html, auto_unbox = TRUE), as.integer(seg * 1000)))
clic <- function() ev("__click()")
mover <- function(xy, seg = .7) { ev(sprintf("__moveCursor(%f, %f, %d)", xy[[1]], xy[[2]], as.integer(seg * 1000))); f(ceiling(seg * FPS) + 2) }
rect <- function(sel) unlist(ev(sprintf("var r=document.querySelector('%s').getBoundingClientRect(); [r.left+r.width/2, r.top+r.height/2]", sel)))
mayor_inciso <- "var n=__red3d.G.graphData().nodes.filter(function(x){return x.t==='inc'}).sort(function(a,b){return b.val-a.val})[0]; n.id"

b$Page$navigate("http://127.0.0.1:8765/red3d.html?rec=1"); Sys.sleep(5)
f(8)
# (cada cuadro = 2 pasos de 16,7 ms: la física avanza como en un navegador a 60 Hz)
# 1) la red de redes
cap("Compras del Estado uruguayo<small>1,8 millones de adjudicaciones · ARCE · 2002–2025</small>", 3.8); f(115)
cap("Cada nodo es un inciso del Estado.<small>Se unen por los proveedores que tienen en común</small>", 4.2); f(128)
# 2) clic: detalle
id <- ev(mayor_inciso); mover(unlist(ev(sprintf("__nodeXY('%s')", id)))); clic()
ev(sprintf("var n=__red3d.G.graphData().nodes.find(function(x){return x.id==='%s'}); __red3d.seleccionar(n); 1", id))
cap("Un clic: detalle y vínculos principales", 3.2); f(100)
# 3) doble clic: entrar al inciso
mover(unlist(ev(sprintf("__nodeXY('%s')", id))), .5); clic(); f(8); clic()
ev(sprintf("var n=__red3d.G.graphData().nodes.find(function(x){return x.id==='%s'}); __red3d.entrar(n); 1", id))
cap("Doble clic: entrás al inciso<small>sus entes, sus proveedores y los «puentes» hacia otros incisos</small>", 5.6); f(185)
# 4) búsqueda
mover(rect("#q")); clic(); f(6)
txt <- "obras sanit"
for (i in seq_len(nchar(txt))) { ev(sprintf("var q=document.getElementById('q'); q.value=%s; q.dispatchEvent(new Event('input'))", jsonlite::toJSON(substr(txt, 1, i), auto_unbox = TRUE))); f(4) }
cap("Buscá cualquier ente o proveedor<small>y mirá su vecindario a dos saltos</small>", 6.4); f(22)
print(ev("document.querySelector('#res div[data-k=\"0\"]').innerText"))
mover(rect("#res div[data-k=\"0\"]"), .6); clic(); f(6)
ev("document.querySelector('#res div[data-k=\"0\"]').click(); 1"); f(185)
# 5) red completa
mover(rect("#modos .chip[data-m=\"completa\"]"), .8); clic(); f(6)
ev("document.querySelector('#modos .chip[data-m=\"completa\"]').click(); 1")
ev("__hideCursor()")
cap("Red completa: los mayores vínculos,<small>coloreados por inciso</small>", 7); f(235)
# 6) cierre
cap("Datos abiertos de ARCE · Compras estatales de Uruguay<small>compras-estatales-uy · github.com/EmilianoGonLas</small>", 4.2); f(128)
cat("cuadros:", k, " duración:", round(k / FPS, 1), "s\n")
system2("ffmpeg", c("-y", "-loglevel", "error", "-framerate", FPS, "-i", file.path(tmp, "f%05d.jpg"),
  "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", salida))
cat("MP4:", salida, round(file.size(salida) / 1e6, 1), "MB\n")
