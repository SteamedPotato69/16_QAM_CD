function verificar_funciones_prohibidas()
% =========================================================================
%  VERIFICAR_FUNCIONES_PROHIBIDAS
%  ------------------------------------------------------------------------
%  Escanea todos los archivos .m del proyecto y verifica que no se usen
%  funciones especiales prohibidas en código ejecutable (cumple RNF3).
%
%  Las siguientes funciones están prohibidas por los requerimientos:
%    qammod, qamdemod, awgn (función toolbox), rcosdesign, eyediagram,
%    pskmod, pskdemod, pwelch, scatterplot.
%
%  El verificador ignora líneas de comentarios (todo lo que sigue a %)
%  y se excluye a sí mismo del análisis.
% =========================================================================

    patrones_prohibidos = {
        '\<qammod\s*\('
        '\<qamdemod\s*\('
        '\<awgn\s*\('
        '\<rcosdesign\s*\('
        '\<eyediagram\s*\('
        '\<pskmod\s*\('
        '\<pskdemod\s*\('
        '\<pwelch\s*\('
        '\<scatterplot\s*\('
    };

    nombres_prohibidos = {
        'qammod', 'qamdemod', 'awgn', 'rcosdesign', 'eyediagram', ...
        'pskmod', 'pskdemod', 'pwelch', 'scatterplot'
    };

    archivos_proyecto = dir(fullfile(pwd, '**', '*.m'));

    fprintf('\n=========================================================\n');
    fprintf('  VERIFICACIÓN DE FUNCIONES PROHIBIDAS (RNF3)\n');
    fprintf('=========================================================\n');

    encontro_algo = false;

    for idx_archivo = 1:length(archivos_proyecto)
        nombre_archivo = archivos_proyecto(idx_archivo).name;

        % El verificador no se analiza a sí mismo.
        if strcmp(nombre_archivo, 'verificar_funciones_prohibidas.m')
            continue;
        end

        ruta_archivo = fullfile(archivos_proyecto(idx_archivo).folder, nombre_archivo);
        texto_archivo = fileread(ruta_archivo);
        lineas = regexp(texto_archivo, '\r\n|\n|\r', 'split');

        for idx_linea = 1:length(lineas)
            linea_actual = lineas{idx_linea};

            % Eliminar parte comentada (todo lo que sigue al primer %).
            pos_comentario = strfind(linea_actual, '%');
            if ~isempty(pos_comentario)
                linea_actual = linea_actual(1:pos_comentario(1)-1);
            end

            % Buscar cada patrón en el código ejecutable restante.
            for idx_func = 1:length(patrones_prohibidos)
                if ~isempty(regexp(linea_actual, patrones_prohibidos{idx_func}, 'once'))
                    fprintf('[ADVERTENCIA] Función prohibida "%s" encontrada en:\n', ...
                        nombres_prohibidos{idx_func});
                    fprintf('  Archivo : %s\n', ruta_archivo);
                    fprintf('  Línea %d : %s\n', idx_linea, strtrim(linea_actual));
                    encontro_algo = true;
                end
            end
        end
    end

    if ~encontro_algo
        fprintf('[OK] No se encontraron funciones prohibidas en código ejecutable.\n');
    end
    fprintf('=========================================================\n\n');

end
