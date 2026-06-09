# Contexto Técnico del Proyecto para LLMs (Asistentes IA)

Este documento detalla la arquitectura, restricciones y decisiones de diseño matemático del repositorio `CANAL_AWGN_CD`. **Instrucción crítica para el LLM:** Si vas a proponer refactorizaciones, añadir funcionalidades o explicar el código, **DEBES respetar estrictamente las restricciones indicadas aquí**, especialmente la prohibición de uso de funciones de Toolboxes especializados.

## 1. Restricciones del Sistema (Requisitos No Funcionales)
* **NO usar `Communications Toolbox`:** Está estrictamente prohibido el uso de funciones como `qammod`, `qamdemod`, `rcosdesign`, `awgn`, `eyediagram`, `scatterplot`, `biterr`.
* **NO usar `Signal Processing Toolbox` para estimación espectral:** Prohibido usar `pwelch` o similares. El espectro se calcula manualmente usando `fft` y ventaneo (`hann`).
* **Reproducibilidad:** Se exige el uso de una semilla estática (`rng(2026)`) fijada en el `main_simulacion.m`.

## 2. Flujo de Procesamiento y Parámetros

El sistema evalúa una transmisión 16-QAM ($M=16$, $k=4$ bits/sim) sobre un canal AWGN. Se realiza un barrido de la relación señal a ruido $E_b/N_0 \in [0, 14]$ dB. Los parámetros por defecto son: $R_s = 1$ baudio, $sps = 8$, $\beta = 0.35$, $span = 6$, y $f_c = 2R_s$.

### A. Modulación y Mapeo (`modulador_binario_16qam.m`)
* Utiliza una cuadrícula de amplitud {-3, -1, 1, 3} para las componentes I y Q.
* Implementa Codificación Gray separable.
* **Normalización:** La energía promedio de la constelación 16-QAM pura es 10. Para lograr $E_s = 1$, los símbolos se dividen por un factor de normalización de $\sqrt{10}$.

### B. Conformación de Pulso (`filtro_coseno_alzado_raiz.m` y `conformacion_pulso.m`)
* El filtro RRC se calcula analíticamente. El código maneja explícitamente las singularidades en $t=0$ (donde el valor es $1 - \beta + 4\beta/\pi$) y en $t = \pm T_s/(4\beta)$ mediante condiciones lógicas.
* El filtro se normaliza a energía unitaria (`sum(h.^2) = 1`).
* El upsampling es manual (inserción de $sps-1$ ceros). La conformación se hace mediante `conv()`, lo que introduce un retardo en el sistema.

### C. Modulación en Banda Pasante (`modulacion_pasabanda.m`)
* La señal compleja a la salida del filtro se traslada a $f_c$.
* Se transmite una señal **estrictamente real**: $s_{pb}(t) = I(t)\cos(2\pi f_c t) - Q(t)\sin(2\pi f_c t)$.

### D. Canal AWGN (`canal_awgn.m`)
* Puesto que la señal que entra al canal es una señal pasabanda real, el ruido inyectado es puramente real (usando `randn` de MATLAB).
* La varianza del ruido se calcula a partir de la potencia pasabanda medida ($P_s$), usando la relación de tasas:
  $\sigma^2 = \frac{P_s \cdot sps}{2 \cdot k \cdot 10^{(E_b/N_0[dB]/10)}}$

### E. Demodulador y Decisor (`demodulador_16qam.m`)
Pipeline completo de recepción:
1. **Down-conversion:** Se multiplica la señal pasabanda recibida por $2\cos(2\pi f_c t)$ para I, y $-2\sin(2\pi f_c t)$ para Q.
2. **Filtro Acoplado:** Convolución con el mismo RRC del transmisor. Actúa como filtro pasa-bajos (eliminando los términos a $2f_c$) y maximiza la SNR.
3. **Muestreo Óptimo:** Calcula el retardo total del sistema: $Retardo = 2 \times span \times sps$. El primer símbolo se extrae en el índice `Retardo + 1` y luego cada $sps$ muestras.
4. **Decisión Dura (Hard Decision):** Los símbolos recibidos se multiplican por $\sqrt{10}$ para devolverlos a la cuadrícula original. Umbrales de decisión uniformes en $I$ y $Q$ definidos en: `<-2`, `[-2, 0)`, `[0, 2)`, `>=2`.
5. **Demapeo Gray Inverso:** Conversión matemática (no mediante Maps/Hash tables por portabilidad a Octave) que mapea los niveles de decisión a los bits correspondientes, obteniendo el vector original concatenado.

### F. Cálculo de Error (`calculo_ber.m`)
* La longitud de los vectores se alinea mediante un `min(length(tx), length(rx))` para ignorar símbolos transitorios de cola producto de la convolución.
* Calcula la BER teórica exacta para M-QAM cuadrada sobre AWGN utilizando la función `erfc`.

### G. Visualización (`graficas_simulacion.m`)
* **Diagrama de Ojo:** Programado manualmente haciendo recortes en matrices de longitud `2 * sps`. Ignora las muestras transitorias iniciales.
* **Espectro:** Transformada de Fourier discreta (`fft`) aplicada directamente a la señal pasabanda tras aplicarle una ventana de Hann manual.
