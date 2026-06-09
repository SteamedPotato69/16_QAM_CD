function coeficientes_h_rrc = ...
            filtro_coseno_alzado_raiz(factor_roll_off_beta,    ...
                                      span_filtro_simbolos,    ...
                                      muestras_por_simbolo_sps)
% =========================================================================
%  FILTRO_COSENO_ALZADO_RAIZ
%  ------------------------------------------------------------------------
%  Calcula los coeficientes del filtro Coseno Alzado Raíz (RRC) de forma
%  analítica.  NO usa la función rcosdesign (cumple RFN3).
%
%  Entradas:
%    factor_roll_off_beta     : β ∈ [0,1]. Controla la transición espectral.
%    span_filtro_simbolos     : Longitud del filtro en SÍMBOLOS, a cada lado
%                               de t=0.  La longitud total en muestras será
%                               L = 2*span*sps + 1.
%    muestras_por_simbolo_sps : Número de muestras por símbolo (sobremuestreo).
%
%  Salida:
%    coeficientes_h_rrc : Vector fila con los coeficientes del filtro RRC,
%                        normalizados con energía unitaria (sum(h.^2)=1).
%
%  ¿Por qué RRC y no RC?
%  ---------------------
%  En un sistema con filtro acoplado en recepción, la respuesta total que
%  ve el símbolo es la cascada Tx*Rx.  Si Tx=RRC y Rx=RRC, entonces
%       Tx * Rx = RC  (Coseno alzado)
%  que cumple el criterio de Nyquist para no-ISI.  Por eso "coseno alzado
%  a lado y lado" significa, en términos correctos, RRC a cada lado.
%
%  Expresión analítica del RRC (Proakis, "Digital Communications"):
%
%             1 - β + 4β/π                                        si t = 0
%   h(t) = ─────────────────────────────────────────────────────────────
%           (β/√2)·[(1+2/π)·sin(π/4β) + (1-2/π)·cos(π/4β)]   si |t|=Ts/(4β)
%
%           sin(π·t/Ts·(1-β)) + 4β·t/Ts·cos(π·t/Ts·(1+β))
%        ─────────────────────────────────────────────────       en otro caso
%           π·t/Ts·(1 - (4β·t/Ts)^2)
% =========================================================================

% Eje temporal del filtro, en muestras.
% L = 2*span*sps + 1  muestras, centradas en 0.
numero_muestras_filtro = 2 * span_filtro_simbolos * muestras_por_simbolo_sps + 1;
eje_temporal_muestras  = -(numero_muestras_filtro-1)/2 : (numero_muestras_filtro-1)/2;

% Eje temporal normalizado al periodo de símbolo Ts.
% (t/Ts) = (n / sps), porque Ts contiene sps muestras.
eje_temporal_normalizado_t_sobre_Ts = eje_temporal_muestras / muestras_por_simbolo_sps;

% Inicializa la salida.
coeficientes_h_rrc = zeros(1, numero_muestras_filtro);

% --- Cálculo punto a punto cubriendo TODAS las singularidades --------------
for indice = 1:numero_muestras_filtro

    t_sobre_Ts = eje_temporal_normalizado_t_sobre_Ts(indice);

    % CASO 1: t = 0   (singularidad de 0/0).
    if abs(t_sobre_Ts) < 1e-12
        coeficientes_h_rrc(indice) = 1 - factor_roll_off_beta + ...
                                     4*factor_roll_off_beta/pi;

    % CASO 2: t = ± Ts/(4β)   (singularidad cuando el denominador se anula).
    elseif factor_roll_off_beta > 0 && ...
           abs(abs(t_sobre_Ts) - 1/(4*factor_roll_off_beta)) < 1e-12
        coeficientes_h_rrc(indice) = (factor_roll_off_beta/sqrt(2)) *               ...
            ( (1 + 2/pi) * sin(pi/(4*factor_roll_off_beta)) +                       ...
              (1 - 2/pi) * cos(pi/(4*factor_roll_off_beta)) );

    % CASO 3: caso general (sin singularidades).
    else
        numerador_rrc = sin(pi*t_sobre_Ts*(1-factor_roll_off_beta)) +               ...
                        4*factor_roll_off_beta*t_sobre_Ts .*                        ...
                        cos(pi*t_sobre_Ts*(1+factor_roll_off_beta));

        denominador_rrc = pi*t_sobre_Ts .*                                          ...
                          (1 - (4*factor_roll_off_beta*t_sobre_Ts).^2);

        coeficientes_h_rrc(indice) = numerador_rrc / denominador_rrc;
    end
end

% --- Normalización a ENERGÍA UNITARIA --------------------------------------
% Esto garantiza que el filtro no amplifique la señal, y que al pasar dos
% veces (Tx + Rx) la ganancia total se mantenga unitaria a la salida del
% filtro acoplado.
coeficientes_h_rrc = coeficientes_h_rrc / sqrt(sum(coeficientes_h_rrc.^2));

end
