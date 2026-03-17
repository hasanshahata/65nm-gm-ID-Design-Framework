% =========================================================================
% Analog IC Design Master Script using gm/ID Methodology
% Technology: 65nm CMOS
% Author: Hassan Shehata
% Institution: Mansoura University
% Date: March 2026
%
% Acknowledgment: This script utilizes the 'lookup' functions developed 
% by Prof. Boris Murmann (Stanford University) for data interpolation.
% =========================================================================

clear all; close all; clc;

%% 1. Load Technology Data & Initialize Workspace
load('65nch.mat'); 
load('65pch.mat'); 

% --- ?????? ?????? ??? PMOS ---
fields = fieldnames(pch);
for k = 1:length(fields)
    if isnumeric(pch.(fields{k}))
        pch.(fields{k}) = abs(pch.(fields{k}));
    end
end
% -----------------------------------------

assignin('base', 'nch', nch);
assignin('base', 'pch', pch);
assignin('base', 'current_dev', 'nch'); 
assignin('base', 'L_array', [0.06, 0.1, 0.2]); 
assignin('base', 'VDS_target', 0.6);           
assignin('base', 'gm_id_range', 5:0.5:25);     
assignin('base', 'last_design_report', 'No design generated yet.');

%% 2. Initialize Main Figure
fig = figure('Name', '65nm Design Space', 'Position', [100, 100, 1200, 400], 'Color', 'w');
update_main_plots(fig); 

%% ========================================================================
%  --- Main Plotting Function ---
% =========================================================================
function update_main_plots(fig)
    clf(fig); 
    set(fig, 'WindowKeyPressFcn', @cadence_shortcuts);
    
    dev_name = evalin('base', 'current_dev');
    dev_data = evalin('base', dev_name);
    L_array = evalin('base', 'L_array');
    VDS_target = evalin('base', 'VDS_target');
    gm_id_range = evalin('base', 'gm_id_range');
    
    if strcmp(dev_name, 'nch')
        title_str = 'NMOS';
    else
        title_str = 'PMOS';
    end
    set(fig, 'Name', sprintf('65nm Design Space - [%s]', title_str));

    % --- Plot 1: fT vs gm/ID ---
    ax1 = subplot(1,3,1); hold on; grid on;
    for i = 1:length(L_array)
        gm_cgg = lookup(dev_data, 'GM_CGG', 'GM_ID', gm_id_range, 'L', L_array(i), 'VDS', VDS_target);
        fT = gm_cgg / (2*pi);
        p = plot(gm_id_range(:), fT(:) / 1e9, 'LineWidth', 2); 
        set(p, 'Tag', 'data_curve'); 
    end
    xlabel('g_m/I_D (V^{-1})'); ylabel('f_T (GHz)');
    title(sprintf('Transit Frequency (%s)', title_str)); 
    legend(arrayfun(@(x) sprintf('L = %g um', x), L_array, 'UniformOutput', false));

    % --- Plot 2: Intrinsic Gain (gm/gds) vs gm/ID ---
    ax2 = subplot(1,3,2); hold on; grid on;
    for i = 1:length(L_array)
        intrinsic_gain = lookup(dev_data, 'GM_GDS', 'GM_ID', gm_id_range, 'L', L_array(i), 'VDS', VDS_target);
        p = plot(gm_id_range(:), intrinsic_gain(:), 'LineWidth', 2); 
        set(p, 'Tag', 'data_curve');
    end
    xlabel('g_m/I_D (V^{-1})'); ylabel('Intrinsic Gain (V/V)');
    title(sprintf('Self-Gain (%s)', title_str)); 
    legend(arrayfun(@(x) sprintf('L = %g um', x), L_array, 'UniformOutput', false));

    % --- Plot 3: Current Density (ID/W) vs gm/ID ---
    ax3 = subplot(1,3,3); hold on; grid on;
    for i = 1:length(L_array)
        id_w = lookup(dev_data, 'ID_W', 'GM_ID', gm_id_range, 'L', L_array(i), 'VDS', VDS_target);
        p = plot(gm_id_range(:), id_w(:), 'LineWidth', 2); 
        set(p, 'Tag', 'data_curve');
    end
    set(gca, 'YScale', 'log'); 
    xlabel('g_m/I_D (V^{-1})'); ylabel('I_D/W (A/\mum)'); 
    title(sprintf('Current Density (%s)', title_str)); 
    legend(arrayfun(@(x) sprintf('L = %g um', x), L_array, 'UniformOutput', false));

    linkaxes([ax1, ax2, ax3], 'x');
    datacursormode off;
end

%% ========================================================================
%  --- Advanced Draggable Cursors & Synthesis Tools ---
% =========================================================================
function cadence_shortcuts(fig, event)
    ax = gca; 
    pt = get(ax, 'CurrentPoint');
    x_val = pt(1,1); y_val = pt(1,2);
    all_axes = findobj(fig, 'Type', 'axes');
    cursor_id = num2str(rand); 
    
    dev_name = evalin('base', 'current_dev');
    dev_data = evalin('base', dev_name);
    
    switch lower(event.Key)
        case 'v' 
            for i = 1:length(all_axes)
                xl = xline(all_axes(i), x_val, 'r-', 'LineWidth', 1.5, 'Label', sprintf(' gm/ID: %.2f ', x_val), 'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'bottom', 'Tag', ['v_cursor_', cursor_id]);
                xl.ButtonDownFcn = @(src, e) startDragVertical(src, fig, cursor_id);
                data_lines = findobj(all_axes(i), 'Tag', 'data_curve');
                for j = 1:length(data_lines)
                    plot(all_axes(i), NaN, NaN, 'ko', 'MarkerFaceColor', 'r', 'Tag', ['v_mark_', cursor_id], 'MarkerSize', 6);
                    text(all_axes(i), NaN, NaN, '', 'BackgroundColor', 'w', 'EdgeColor', 'r', 'Tag', ['v_text_', cursor_id], 'FontSize', 8, 'Margin', 2, 'VerticalAlignment', 'bottom');
                end
            end
            updateVerticalIntersections(fig, cursor_id, x_val);
            
        case 'h' 
            yl = yline(ax, y_val, 'b-', 'LineWidth', 1.5, 'Label', sprintf(' y: %.2g ', y_val), 'LabelHorizontalAlignment', 'left', 'Tag', ['h_cursor_', cursor_id]);
            yl.ButtonDownFcn = @(src, e) startDragHorizontal(src, fig, cursor_id);
            data_lines = findobj(ax, 'Tag', 'data_curve');
            for j = 1:length(data_lines)
                plot(ax, NaN, NaN, 'ko', 'MarkerFaceColor', 'b', 'Tag', ['h_mark_', cursor_id], 'MarkerSize', 6);
                text(ax, NaN, NaN, '', 'BackgroundColor', 'w', 'EdgeColor', 'b', 'Tag', ['h_text_', cursor_id], 'FontSize', 8, 'Margin', 2, 'VerticalAlignment', 'bottom');
            end
            updateHorizontalIntersections(ax, cursor_id, y_val);
                
        case 'c' 
            delete(findobj(fig, '-regexp', 'Tag', '^(v_|h_)'));
            
        case 't' 
            if strcmp(dev_name, 'nch')
                assignin('base', 'current_dev', 'pch');
                fprintf('\n---> Switched to PMOS mode <---\n');
            else
                assignin('base', 'current_dev', 'nch');
                fprintf('\n---> Switched to NMOS mode <---\n');
            end
            update_main_plots(fig);

        case 'f' 
            L_array = evalin('base', 'L_array');
            VDS_target = evalin('base', 'VDS_target');
            gm_id_range = evalin('base', 'gm_id_range');
            
            fom_fig = figure('Name', sprintf('Figure of Merit (%s)', upper(dev_name(1))), 'Color', 'w');
            set(fom_fig, 'WindowKeyPressFcn', @cadence_shortcuts);
            hold on; grid on; leg_str = {};
            
            for i = 1:length(L_array)
                gm_cgg = lookup(dev_data, 'GM_CGG', 'GM_ID', gm_id_range, 'L', L_array(i), 'VDS', VDS_target);
                fT = gm_cgg / (2*pi);
                FoM = gm_id_range(:) .* fT(:); 
                
                p_curve = plot(gm_id_range(:), FoM / 1e9, 'LineWidth', 2);
                set(p_curve, 'Tag', 'data_curve'); 
                leg_str{end+1} = sprintf('L = %g um', L_array(i));
            end
            
            xlabel('g_m/I_D (V^{-1})'); ylabel('FoM: (g_m/I_D) \times f_T (GHz/V)');
            title(sprintf('Figure of Merit (Speed vs Power) - %s', upper(dev_name(1))));
            legend(leg_str);
            
        case 'e' 
            report_str = evalin('base', 'last_design_report');
            if strcmp(report_str, 'No design generated yet.')
                errordlg('Please generate a design first using "s" or "d" before exporting.', 'Export Error');
                return;
            end
            prompt = {'Enter Block Name (e.g., M1_TailCurrent):'};
            answer = inputdlg(prompt, 'Export Design Log', [1 40], {'M1_Block'});
            if isempty(answer), return; end
            
            block_name = strtrim(answer{1});
            filename = 'VGA_Design_Log.txt';
            
            fid = fopen(filename, 'a'); 
            fprintf(fid, '\n==================================================================\n');
            fprintf(fid, ' BLOCK: %s | DEVICE: %s | DATE: %s\n', upper(block_name), upper(dev_name(1)), datestr(now, 'yyyy-mm-dd HH:MM'));
            fprintf(fid, '%s', report_str);
            fclose(fid);
            fprintf('\n---> Design exported successfully to %s <---\n', filename);

        case 'p' 
            prompt = {'Y-Axis Variable (e.g., CGG_W, VT, GM_GDS, ID_W):', 'Length(s) L in um (e.g., 0.06:0.02:0.12):', 'V_DS (V):'};
            answer = inputdlg(prompt, 'Custom Plot Generator', [1 60], {'CGG_W', '0.06:0.02:0.1', '0.6'}); 
            if isempty(answer), return; end
            
            y_var = strtrim(upper(answer{1})); 
            custom_L = str2num(answer{2}); 
            custom_vds = str2double(answer{3});
            if isempty(custom_L), errordlg('Invalid Length format.', 'Input Error'); return; end
            
            gm_id_range = evalin('base', 'gm_id_range');
            new_fig = figure('Name', sprintf('Custom Plot: %s', y_var), 'Color', 'w');
            set(new_fig, 'WindowKeyPressFcn', @cadence_shortcuts); 
            hold on; grid on; leg_str = {};
            
            for i = 1:length(custom_L)
                try
                    y_data = lookup(dev_data, y_var, 'GM_ID', gm_id_range, 'L', custom_L(i), 'VDS', custom_vds);
                    if strcmp(y_var, 'GM_CGG'), y_data = y_data / (2*pi*1e9); end
                    
                    p_curve = plot(gm_id_range(:), y_data(:), 'LineWidth', 2); 
                    set(p_curve, 'Tag', 'data_curve'); 
                    
                    leg_str{end+1} = sprintf('L = %g um', custom_L(i));
                catch
                    errordlg(sprintf('Cannot plot "%s" for L = %g.', y_var, custom_L(i)), 'Lookup Error'); close(new_fig); return;
                end
            end
            xlabel('g_m/I_D (V^{-1})');
            if strcmp(y_var, 'GM_CGG'), ylabel('f_T (GHz)');
            elseif strcmp(y_var, 'ID_W'), ylabel('I_D/W (A/\mum)'); set(gca, 'YScale', 'log'); 
            else ylabel(y_var, 'Interpreter', 'none'); end
            title(sprintf('%s vs g_m/I_D (@ V_{DS} = %gV) [%s]', y_var, custom_vds, upper(dev_name(1))), 'Interpreter', 'none');
            legend(leg_str);

        case 's' 
            prompt = {'Enter Target gm (in uS):'}; 
            answer = inputdlg(prompt, 'VGA Auto-Sizing (Fixed L)', [1 40], {'1000'}); 
            if isempty(answer), return; end
            
            target_gm = str2double(answer{1}) * 1e-6; 
            target_gmid = x_val; 
            L_array = evalin('base', 'L_array'); VDS_target = evalin('base', 'VDS_target');
            
            rep = sprintf('==================================================================\n');
            rep = [rep, sprintf('   AUTO-SIZING REPORT (Target gm = %.2f uS @ gm/ID = %.1f V^-1)\n', target_gm*1e6, target_gmid)];
            rep = [rep, sprintf('==================================================================\n')];
            rep = [rep, sprintf(' L (um) |   W (um)   |  I_D (uA)  |  V_GS (V)  | C_gg (fF) \n')];
            rep = [rep, sprintf('------------------------------------------------------------------\n')];
            
            for i = 1:length(L_array)
                ID_req = target_gm / target_gmid;
                id_w = lookup(dev_data, 'ID_W', 'GM_ID', target_gmid, 'L', L_array(i), 'VDS', VDS_target);
                W_req = ID_req / id_w; 
                vgs_req = lookupVGS(dev_data, 'GM_ID', target_gmid, 'L', L_array(i), 'VDS', VDS_target);
                cgg_w = lookup(dev_data, 'CGG_W', 'GM_ID', target_gmid, 'L', L_array(i), 'VDS', VDS_target);
                Cgg_total = cgg_w * W_req;
                rep = [rep, sprintf(' %-6.2f | %-10.2f | %-10.2f | %-10.3f | %-10.2f\n', L_array(i), W_req, ID_req*1e6, vgs_req, Cgg_total*1e15)];
            end
            rep = [rep, sprintf('==================================================================\n')];
            
            fprintf('\n%s', rep);
            assignin('base', 'last_design_report', rep); 

        case 'd' 
            try VDS_target = evalin('base', 'VDS_target'); catch, VDS_target = 0.6; end
            prompt = {'gm/ID (V^-1):', 'Target I_D (uA):', 'V_DS (V):', 'Target Gain (gm/gds) [V/V]:'};
            answer = inputdlg(prompt, 'Exact Sizing (Find L & W)', [1 40], {num2str(round(x_val,1)), '50', num2str(VDS_target), '20'}); 
            if isempty(answer), return; end
            
            req_gmid = str2double(answer{1}); req_id = str2double(answer{2}) * 1e-6; 
            req_vds = str2double(answer{3}); req_gain = str2double(answer{4});
            
            dense_L = 0.06:0.01:1.0; 
            gain_across_L = lookup(dev_data, 'GM_GDS', 'GM_ID', req_gmid, 'L', dense_L, 'VDS', req_vds);
            
            min_gain = min(gain_across_L); max_gain = max(gain_across_L);
            
            rep = sprintf('==================================================================\n');
            rep = [rep, sprintf('   EXACT DESIGN REPORT\n')];
            rep = [rep, sprintf('   Inputs: gm/ID = %.1f, I_D = %.1f uA, V_DS = %.2f V, Gain = %.1f\n', req_gmid, req_id*1e6, req_vds, req_gain)];
            rep = [rep, sprintf('==================================================================\n')];

            if req_gain < min_gain || req_gain > max_gain
                rep = [rep, sprintf(' [WARNING] Target Gain (%.1f) is NOT POSSIBLE at this gm/ID!\n', req_gain)];
                rep = [rep, sprintf(' Max possible Gain is %.1f (at L=1um), Min is %.1f (at L=0.06um).\n', max_gain, min_gain)];
                rep = [rep, sprintf('==================================================================\n')];
                fprintf('\n%s', rep); return;
            end
            
            [gain_uniq, sort_idx] = unique(gain_across_L); L_uniq = dense_L(sort_idx);
            req_L = interp1(gain_uniq, L_uniq, req_gain, 'linear');
            req_id_w = lookup(dev_data, 'ID_W', 'GM_ID', req_gmid, 'L', req_L, 'VDS', req_vds);
            req_W = req_id / req_id_w;
            req_vgs = lookupVGS(dev_data, 'GM_ID', req_gmid, 'L', req_L, 'VDS', req_vds);
            req_gm = req_gmid * req_id;
            
            rep = [rep, sprintf(' -> Required Length (L)  : %.4f um\n', req_L)];
            rep = [rep, sprintf(' -> Required Width  (W)  : %.2f um\n', req_W)];
            rep = [rep, sprintf(' -> Resulting gm         : %.2f uS\n', req_gm*1e6)];
            rep = [rep, sprintf(' -> Required Bias (V_GS) : %.3f V\n', req_vgs)];
            rep = [rep, sprintf('==================================================================\n')];
            
            fprintf('\n%s', rep);
            assignin('base', 'last_design_report', rep); 
    end
end

% --- Drag & Intersect Logic (Vertical) ---
function startDragVertical(~, fig, cursor_id)
    set(fig, 'WindowButtonMotionFcn', {@dragVertical, fig, cursor_id}, 'WindowButtonUpFcn', @stopDrag);
end
function dragVertical(~, ~, fig, cursor_id)
    ax = gca; pt = get(ax, 'CurrentPoint'); new_x = pt(1,1);
    lines = findobj(fig, 'Tag', ['v_cursor_', cursor_id]);
    for i = 1:length(lines), lines(i).Value = new_x; lines(i).Label = sprintf(' gm/ID: %.2f ', new_x); end
    updateVerticalIntersections(fig, cursor_id, new_x);
end
function updateVerticalIntersections(fig, cursor_id, new_x)
    all_axes = findobj(fig, 'Type', 'axes');
    markers = findobj(fig, 'Tag', ['v_mark_', cursor_id]); texts = findobj(fig, 'Tag', ['v_text_', cursor_id]);
    idx = 1;
    for i = 1:length(all_axes)
        data_lines = findobj(all_axes(i), 'Tag', 'data_curve');
        for j = 1:length(data_lines)
            xd = data_lines(j).XData; yd = data_lines(j).YData;
            if new_x >= min(xd) && new_x <= max(xd)
                [xd_uniq, i_uniq] = unique(xd); yd_uniq = yd(i_uniq);
                y_int = interp1(xd_uniq, yd_uniq, new_x, 'linear'); 
                markers(idx).XData = new_x; markers(idx).YData = y_int;
                texts(idx).Position = [new_x, y_int, 0]; texts(idx).String = sprintf(' %.2g', y_int);
            else
                markers(idx).XData = NaN; markers(idx).YData = NaN; texts(idx).String = '';
            end
            idx = idx + 1;
        end
    end
end

% --- Drag & Intersect Logic (Horizontal) ---
function startDragHorizontal(~, fig, cursor_id)
    set(fig, 'WindowButtonMotionFcn', {@dragHorizontal, fig, cursor_id}, 'WindowButtonUpFcn', @stopDrag);
end
function dragHorizontal(~, ~, fig, cursor_id)
    ax = gca; pt = get(ax, 'CurrentPoint'); new_y = pt(1,2);
    lines = findobj(ax, 'Tag', ['h_cursor_', cursor_id]);
    for i = 1:length(lines), lines(i).Value = new_y; lines(i).Label = sprintf(' y: %.2g ', new_y); end
    updateHorizontalIntersections(ax, cursor_id, new_y);
end
function updateHorizontalIntersections(ax, cursor_id, new_y)
    markers = findobj(ax, 'Tag', ['h_mark_', cursor_id]); texts = findobj(ax, 'Tag', ['h_text_', cursor_id]);
    data_lines = findobj(ax, 'Tag', 'data_curve');
    for j = 1:length(data_lines)
        xd = data_lines(j).XData; yd = data_lines(j).YData;
        [yd_sort, sort_idx] = sort(yd); xd_sort = xd(sort_idx);
        [yd_uniq, i_uniq] = unique(yd_sort); xd_uniq = xd_sort(i_uniq);
        if new_y >= min(yd_uniq) && new_y <= max(yd_uniq)
            x_int = interp1(yd_uniq, xd_uniq, new_y, 'linear'); 
            markers(j).XData = x_int; markers(j).YData = new_y;
            texts(j).Position = [x_int, new_y, 0]; texts(j).String = sprintf(' gm/ID: %.2f', x_int);
        else
            markers(j).XData = NaN; markers(j).YData = NaN; texts(j).String = '';
        end
    end
end
function stopDrag(fig, ~)
    set(fig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
end