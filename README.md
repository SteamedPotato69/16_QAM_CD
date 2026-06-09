# Simulación de Sistema de Comunicaciones Digitales: 16-QAM sobre Canal AWGN

Este repositorio contiene una simulación modular desarrollada en **MATLAB** de un sistema completo de comunicaciones digitales. El proyecto abarca desde la generación de bits y modulación, hasta la transmisión en banda pasante, modelado de canal AWGN y recepción con filtro acoplado, cumpliendo con estrictos requerimientos académicos.

## 🚀 Características Principales

* **Modulación:** 16-QAM ($M=16$, $k=4$ bits/símbolo) utilizando codificación Gray bidimensional.
* **Conformación de Pulso:** Filtro de Coseno Alzado Raíz (RRC) implementado analíticamente, garantizando el criterio de Nyquist para cero Interferencia Entre Símbolos (ISI) al acoplarse en Tx y Rx.
* **Transmisión en Banda Pasante:** Modulación y demodulación a una frecuencia portadora $f_c$, trabajando con señales puramente reales en el canal.
* **Modelo de Canal:** Canal de Ruido Blanco Gaussiano Aditivo (AWGN) con calibración precisa de varianza basada en la relación $E_b/N_0$.
* **Desarrollo "Desde Cero" (Zero-Toolbox):** El código **NO** utiliza funciones preconstruidas de toolboxes específicos de telecomunicaciones (como `qammod`, `rcosdesign`, `eyediagram`, `scatterplot` o `pwelch`). Toda la lógica, filtrado, demapeo y gráficas están construidos desde las matemáticas base.

## 📁 Estructura del Proyecto

El sistema está diseñado bajo una arquitectura de alta cohesión y bajo acoplamiento:

* `main_simulacion.m`: Script principal que orquesta la configuración, el barrido de $E_b/N_0$ y la generación de gráficas.
* `modulador_binario_16qam.m`: Generación de bits aleatorios y mapeo a símbolos complejos 16-QAM normalizados.
* `filtro_coseno_alzado_raiz.m`: Diseño analítico del filtro RRC resolviendo las singularidades matemáticas.
* `conformacion_pulso.m`: Upsampling manual y convolución con el filtro RRC.
* `modulacion_pasabanda.m`: Traslación espectral de la señal banda base a la portadora de RF.
* `canal_awgn.m`: Contaminación de la señal real pasabanda con ruido gaussiano calculado a partir del $E_b/N_0$.
* `demodulador_16qam.m`: Pipeline de recepción completo (down-conversion, filtro acoplado, muestreo óptimo, decisión dura y demapeo Gray inverso).
* `calculo_ber.m`: Cálculo de la Tasa de Error de Bit (BER) empírica y teórica.
* `graficas_simulacion.m`: Módulo de visualización independiente (Curva BER, Constelación, Diagrama de Ojo y Espectro).

## ⚙️ Cómo Ejecutar

1. Clona este repositorio en tu máquina local.
2. Abre MATLAB y navega hasta el directorio del repositorio.
3. Abre y ejecuta el archivo `main_simulacion.m`.
4. El script realizará un barrido de relaciones $E_b/N_0$ (de 0 a 14 dB) e imprimirá los resultados en la consola. Al finalizar, se desplegarán 4 figuras con el análisis técnico del sistema.

## 📊 Resultados Esperados

Al ejecutar la simulación, el sistema generará automáticamente:
1. **Curva BER vs Eb/No:** Comparación logarítmica entre el desempeño simulado y el límite teórico.
2. **Diagrama de Constelación:** Dispersión I-Q de los símbolos recibidos tras el filtro acoplado.
3. **Diagrama de Ojo:** Visualización de las componentes en fase y cuadratura para el análisis cualitativo de la ISI.
4. **Espectro de la Señal Pasabanda:** Densidad espectral calculada mediante FFT directa con ventaneo Hann.
