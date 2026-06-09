function [audio_muestras, fs_audio] = generar_audio_prueba(ruta_guardado)
% =========================================================================
%  GENERAR_AUDIO_PRUEBA
%  ------------------------------------------------------------------------
%  Genera una señal de audio de prueba de 10 segundos compuesta por un
%  acorde de tonos sinusoidales (A4 + E5 + A5) con envolvente ADSR suave.
%  El audio se guarda en formato WAV y se devuelve como vector de muestras.
%
%  NO utiliza funciones de Audio Toolbox.  Solo operaciones matemáticas
%  básicas y audiowrite (función nativa de MATLAB, no pertenece a
%  toolboxes especializados de comunicaciones).
%
%  Características del audio generado:
%    - Duración      : 10 segundos
%    - Frecuencias   : 440 Hz (La4) + 659 Hz (Mi5) + 880 Hz (La5)
%    - Fs            : 44100 Hz (estándar CD)
%    - Canales       : 1 (mono)
%    - Amplitud      : normalizada a [-1, 1]
%
%  Entradas:
%    ruta_guardado : (opcional) Ruta completa donde guardar el .wav.
%                   Por defecto: './audio_prueba.wav' en la carpeta Audio/.
%
%  Salidas:
%    audio_muestras : Vector columna de muestras en [-1, 1].
%    fs_audio       : Frecuencia de muestreo [Hz].
% =========================================================================

    if nargin < 1 || isempty(ruta_guardado)
        % Guardar junto a este script.
        carpeta_actual = fileparts(mfilename('fullpath'));
        ruta_guardado  = fullfile(carpeta_actual, 'audio_prueba.wav');
    end

    % ------------------------------------------------------------------
    % Parámetros del audio de prueba.
    % ------------------------------------------------------------------
    fs_audio     = 44100;          % Frecuencia de muestreo [Hz]
    duracion_s   = 10;             % Duración total [s]
    N            = fs_audio * duracion_s;
    t            = (0:N-1)' / fs_audio;   % Vector de tiempo [s] (columna)

    % Frecuencias del acorde A mayor (La4 – Mi5 – La5).
    f1 = 440;    % La4  [Hz]
    f2 = 659;    % Mi5  [Hz] (aproximación de la5 * 3/2 ≈ 659.3)
    f3 = 880;    % La5  [Hz]

    % Amplitudes relativas (la fundamental domina ligeramente).
    A1 = 0.50;
    A2 = 0.35;
    A3 = 0.25;

    % ------------------------------------------------------------------
    % Envolvente ADSR — hace más natural el audio y evita discontinuidades.
    %
    %   Attack  : 0   – 0.5 s (rampa ascendente)
    %   Decay   : 0.5 – 1.0 s (caída suave al nivel sustain)
    %   Sustain : 1.0 – 9.0 s (nivel constante = 1.0)
    %   Release : 9.0 – 10  s (rampa descendente a 0)
    % ------------------------------------------------------------------
    envolvente = ones(N, 1);

    % Attack
    t_ataque     = 0.5;
    idx_ataque   = round(t_ataque * fs_audio);
    envolvente(1:idx_ataque) = linspace(0, 1, idx_ataque)';

    % Decay
    t_decay      = 1.0;
    idx_decay    = round(t_decay * fs_audio);
    nivel_sustain = 0.85;
    envolvente(idx_ataque+1:idx_decay) = ...
        linspace(1, nivel_sustain, idx_decay - idx_ataque)';

    % Sustain (ya está en 1.0 × nivel_sustain por defecto)
    envolvente(idx_decay+1:end) = nivel_sustain;

    % Release
    t_release    = 9.0;
    idx_release  = round(t_release * fs_audio);
    envolvente(idx_release+1:end) = ...
        linspace(nivel_sustain, 0, N - idx_release)';

    % ------------------------------------------------------------------
    % Síntesis aditiva: suma de tres sinusoides + envolvente ADSR.
    % ------------------------------------------------------------------
    tono_1 = A1 * sin(2*pi*f1 * t);
    tono_2 = A2 * sin(2*pi*f2 * t);
    tono_3 = A3 * sin(2*pi*f3 * t);

    audio_raw = (tono_1 + tono_2 + tono_3) .* envolvente;

    % Normalizar a [-1, 1] para evitar clipping y maximizar la resolución ADC.
    amplitud_pico = max(abs(audio_raw));
    if amplitud_pico > 0
        audio_muestras = audio_raw / amplitud_pico;
    else
        audio_muestras = audio_raw;
    end

    % ------------------------------------------------------------------
    % Guardar como WAV de 16 bits.
    % ------------------------------------------------------------------
    audiowrite(ruta_guardado, audio_muestras, fs_audio, 'BitsPerSample', 16);

    fprintf('[Audio] Señal de prueba generada: %d muestras, %.1f s, %.0f Hz\n', ...
        N, duracion_s, fs_audio);
    fprintf('[Audio] Archivo guardado en: %s\n', ruta_guardado);

end
