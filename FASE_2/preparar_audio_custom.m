%% preparar_audio_custom.m
% Prepara un audio local para usarlo como entrada oficial de Fase II.
% Genera FASE_2/Audio/audio_prueba.wav en formato:
% WAV, mono, 44100 Hz, entre 10 y 20 segundos, 16 bits.
%
% Reglas de duración:
%   < 10 s  → se rechaza con error (audio demasiado corto)
%   10-20 s → se acepta tal cual
%   > 20 s  → se recorta a 20 segundos

DURACION_MIN_S = 10;
DURACION_MAX_S = 20;

clear;
clc;
close all;

[archivo, carpeta] = uigetfile( ...
    {'*.wav;*.mp3;*.m4a;*.flac', 'Archivos de audio'}, ...
    'Selecciona tu audio local');

if isequal(archivo, 0)
    error('No seleccionaste ningún archivo.');
end

rutaEntrada = fullfile(carpeta, archivo);
[x, fsOriginal] = audioread(rutaEntrada);

fprintf('Audio cargado: %s\n', rutaEntrada);
fprintf('Fs original = %.0f Hz\n', fsOriginal);
fprintf('Duración original = %.2f s\n', length(x)/fsOriginal);

% Convertir a mono si es estéreo
if size(x, 2) > 1
    x = mean(x, 2);
    fprintf('Audio convertido a mono.\n');
end

% Remuestrear manualmente a 44100 Hz si hace falta
fsObjetivo = 44100;

if fsOriginal ~= fsObjetivo
    tOriginal = (0:length(x)-1)' / fsOriginal;
    tNuevo = (0:1/fsObjetivo:tOriginal(end))';
    x = interp1(tOriginal, x, tNuevo, 'linear', 0);
    fprintf('Audio remuestreado a 44100 Hz.\n');
end

% Validar y ajustar duración.
duracion_actual = length(x) / fsObjetivo;
fprintf('Duración tras remuestreo: %.2f s\n', duracion_actual);

if duracion_actual < DURACION_MIN_S
    error('El audio dura %.1f s, mínimo requerido = %d s. Usa un audio más largo.', ...
        duracion_actual, DURACION_MIN_S);
end

if duracion_actual > DURACION_MAX_S
    x = x(1 : DURACION_MAX_S * fsObjetivo);
    fprintf('Audio recortado a %d segundos (máximo permitido).\n', DURACION_MAX_S);
else
    fprintf('Duración aceptada: %.2f s (entre %d y %d s).\n', ...
        duracion_actual, DURACION_MIN_S, DURACION_MAX_S);
end

% Normalizar para evitar saturación
maxAbs = max(abs(x));
if maxAbs > 0
    x = 0.98 * x / maxAbs;
end

% Guardar en FASE_2/Audio/audio_prueba.wav
carpetaSalida = fullfile(pwd, 'Audio');

if ~exist(carpetaSalida, 'dir')
    mkdir(carpetaSalida);
end

rutaSalida = fullfile(carpetaSalida, 'audio_prueba.wav');
audiowrite(rutaSalida, x, fsObjetivo, 'BitsPerSample', 16);

fprintf('\nAudio preparado correctamente.\n');
fprintf('Guardado en: %s\n', rutaSalida);
fprintf('Fs final = %.0f Hz\n', fsObjetivo);
fprintf('Duración final = %.2f s\n', length(x)/fsObjetivo);
fprintf('Formato final: WAV, mono, 16 bits (entre %d y %d s).\n', ...
    DURACION_MIN_S, DURACION_MAX_S);