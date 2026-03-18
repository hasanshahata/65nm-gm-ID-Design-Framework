% =========================================================================
% Analog IC Design Master Script -- gm/ID Methodology
% Technology : TSMC 65nm CMOS
%
% Author      : Hassan Shehata Ali
% Institution : Mansoura University
% Date        : March 2026
%
% Acknowledgment: lookup / lookupVGS functions by Prof. Boris Murmann
%                 (Stanford University).
%
% KEYBOARD SHORTCUTS (focus any plot window):
%   V  -- drop a draggable vertical marker  (all linked axes)
%   H  -- drop a draggable horizontal marker
%   C  -- clear all markers
%   T  -- toggle NMOS / PMOS
%   F  -- Figure-of-Merit  (gm/ID x fT)
%   P  -- custom plot (any lookup variable)
%   S  -- auto-sizing   (target gm, fixed L-array)
%   D  -- exact sizing  (find L & W for target gain)
%   I  -- complete transistor profiler
%   E  -- export last report to Design_Log.txt
% =========================================================================

clear; close all; clc;

%% 1. Load Technology Data
load('65nch.mat');
load('65pch.mat');

% PMOS: absolute values (avoid sign issues in interpolation)
for fn = fieldnames(pch)'
    if isnumeric(pch.(fn{1}))
        pch.(fn{1}) = abs(pch.(fn{1}));
    end
end

%% 2. Global Colour / Style Palette  (edit here to retheme everything)
CLR.bg         = [0.10  0.12  0.16];   % dark canvas
CLR.panel      = [0.14  0.17  0.22];   % slightly lighter panel
CLR.grid       = [0.25  0.28  0.35];
CLR.ax_fg      = [0.88  0.90  0.94];   % axis labels / ticks
CLR.nmos_lines = {[0.27 0.73 1.00];    % blue family
                  [0.00 0.53 0.90];
                  [0.40 0.85 1.00];
                  [0.60 0.90 1.00]};
CLR.pmos_lines = {[1.00 0.42 0.42];    % red family
                  [0.95 0.25 0.25];
                  [1.00 0.65 0.35];
                  [1.00 0.80 0.40]};
CLR.marker_v   = [1.00 0.82 0.20];     % vertical cursor
CLR.marker_h   = [0.35 1.00 0.60];     % horizontal cursor
CLR.op_dot     = [1.00 0.35 0.35];     % operating-point dot
CLR.accent     = [0.27 0.73 1.00];

%% 3. State Struct (stored in figure appdata -- no base-workspace pollution)
State.nch              = nch;
State.pch              = pch;
State.current_dev      = 'nch';
State.L_array          = [0.5];
State.VDS_target       = 0.6;
State.gm_id_range      = 5:0.5:30;
State.last_design_report = 'No design generated yet.';
State.CLR              = CLR;

%% 4. Launch
fig = figure('Name','TSMC 65nm  |  gm/ID Design Space', ...
             'Position',[80 120 1280 420], ...
             'Color', CLR.bg);
setappdata(fig,'State',State);
update_main_plots(fig);

% =========================================================================
%  MAIN PLOT  (call after any state change)
% =========================================================================
function update_main_plots(fig)
    clf(fig);
    set(fig,'WindowKeyPressFcn',@(f,e) cadence_shortcuts(f,e));

    State    = getappdata(fig,'State');
    CLR      = State.CLR;
    dev_data = State.(State.current_dev);
    L        = State.L_array;
    VDS      = State.VDS_target;
    gmid     = State.gm_id_range;
    isN      = strcmp(State.current_dev,'nch');
    dlabel   = 'NMOS'; if ~isN, dlabel='PMOS'; end
    colors   = CLR.nmos_lines; if ~isN, colors=CLR.pmos_lines; end

    set(fig,'Name',sprintf('TSMC 65nm  |  gm/ID Design Space  [%s]  VDS=%.2fV', dlabel, VDS));

    nL  = numel(L);
    leg = cell(1,nL);
    for k=1:nL, leg{k}=sprintf('L = %g um', L(k)); end

    titles = {'Transit Frequency  f_T', ...
              'Intrinsic Gain  g_m/g_{ds}', ...
              'Current Density  I_D/W'};
    ylabs  = {'f_T  (GHz)', 'Gain  (V/V)', 'I_D/W  (A/um)'};

    for sp = 1:3
        ax = subplot(1,3,sp);
        style_axes(ax, CLR);
        hold(ax,'on');

        for k = 1:nL
            c = colors{mod(k-1,numel(colors))+1};
            switch sp
                case 1
                    yd = lookup(dev_data,'GM_CGG','GM_ID',gmid,'L',L(k),'VDS',VDS)/(2*pi*1e9);
                case 2
                    yd = lookup(dev_data,'GM_GDS','GM_ID',gmid,'L',L(k),'VDS',VDS);
                case 3
                    yd = lookup(dev_data,'ID_W',  'GM_ID',gmid,'L',L(k),'VDS',VDS);
            end
            plot(ax, gmid, yd, 'Color',c, 'LineWidth',2.2, 'Tag','data_curve');
        end

        if sp==3, set(ax,'YScale','log'); end

        xlabel(ax,'g_m/I_D  (1/V)','Color',CLR.ax_fg,'FontSize',10);
        ylabel(ax, ylabs{sp},      'Color',CLR.ax_fg,'FontSize',10);
        title(ax,  titles{sp},     'Color',CLR.ax_fg,'FontSize',11,'FontWeight','bold');

        lg = legend(ax, leg, 'Location','best');
        set(lg,'TextColor',CLR.ax_fg,'Color',CLR.panel,'EdgeColor',CLR.grid,'FontSize',8.5);
    end

    all_ax = findobj(fig,'Type','axes');
    linkaxes(all_ax,'x');

    % Shared subtitle
    annotation(fig,'textbox',[0 0.01 1 0.04], ...
        'String', sprintf('[%s]   VDS = %.2fV   |   Press: V H C T F P S D I E', dlabel, VDS), ...
        'Color',[0.55 0.65 0.75], 'FontSize',8.5, 'EdgeColor','none', ...
        'HorizontalAlignment','center','VerticalAlignment','middle');
end

% =========================================================================
%  KEYBOARD DISPATCHER
% =========================================================================
function cadence_shortcuts(fig, event)
    State    = getappdata(fig,'State');
    CLR      = State.CLR;
    dev_data = State.(State.current_dev);
    ax       = gca;
    pt       = get(ax,'CurrentPoint');
    x_val    = pt(1,1);
    all_axes = findobj(fig,'Type','axes');
    cid      = sprintf('%08x', mod(round(rand*1e8),2^31));

    switch lower(event.Key)

        % ================================================================
        case 'v'   % Vertical marker (all axes)
            for i = 1:numel(all_axes)
                xl = xline(all_axes(i), x_val, ...
                    'Color',CLR.marker_v, 'LineWidth',1.8, ...
                    'Label',sprintf('  gm/ID=%.2f  ',x_val), ...
                    'Tag',['v_cursor_' cid]);
                xl.ButtonDownFcn = @(s,~) startDragV(s,fig,cid);
                n_curves_v = numel(findobj(all_axes(i),'Tag','data_curve'));
                for jv = 1:n_curves_v
                    plot(all_axes(i),NaN,NaN,'o','Color',CLR.marker_v, ...
                        'MarkerFaceColor',CLR.marker_v,'MarkerSize',6, ...
                        'Tag',['v_mark_' cid]);
                    text(all_axes(i),NaN,NaN,'','Color',CLR.marker_v, ...
                        'BackgroundColor',CLR.panel,'EdgeColor',CLR.marker_v, ...
                        'Tag',['v_text_' cid],'FontSize',8,'Margin',2, ...
                        'VerticalAlignment','bottom');
                end
            end
            updateVI(fig,cid,x_val);

        % ================================================================
        case 'h'   % Horizontal marker (current axis)
            y_val = pt(1,2);
            yl = yline(ax, y_val, ...
                'Color',CLR.marker_h, 'LineWidth',1.8, ...
                'Label',sprintf('  y=%.3g  ',y_val), ...
                'Tag',['h_cursor_' cid]);
            yl.ButtonDownFcn = @(s,~) startDragH(s,fig,cid);
            n_curves_h = numel(findobj(ax,'Tag','data_curve'));
            for jh = 1:n_curves_h
                plot(ax,NaN,NaN,'o','Color',CLR.marker_h, ...
                    'MarkerFaceColor',CLR.marker_h,'MarkerSize',6, ...
                    'Tag',['h_mark_' cid]);
                text(ax,NaN,NaN,'','Color',CLR.marker_h, ...
                    'BackgroundColor',CLR.panel,'EdgeColor',CLR.marker_h, ...
                    'Tag',['h_text_' cid],'FontSize',8,'Margin',2, ...
                    'VerticalAlignment','bottom');
            end
            updateHI(ax,cid,y_val);

        % ================================================================
        case 'c'
            delete(findobj(fig,'-regexp','Tag','^(v_|h_)'));

        % ================================================================
        case 't'
            if strcmp(State.current_dev,'nch')
                State.current_dev = 'pch';
                fprintf('---> Switched to PMOS\n');
            else
                State.current_dev = 'nch';
                fprintf('---> Switched to NMOS\n');
            end
            setappdata(fig,'State',State);
            update_main_plots(fig);

        % ================================================================
        case 'f'   % Figure of Merit
            gmid = State.gm_id_range;
            nL   = numel(State.L_array);
            leg  = cell(1,nL);
            isN  = strcmp(State.current_dev,'nch');
            colors = CLR.nmos_lines; if ~isN, colors=CLR.pmos_lines; end

            ff = figure('Name',sprintf('Figure of Merit  [%s]', upper(State.current_dev)), ...
                        'Color',CLR.bg,'Position',[160 130 640 440]);
            set(ff,'WindowKeyPressFcn',@(f,e) cadence_shortcuts(f,e));
            setappdata(ff,'State',State);
            ax = axes('Parent',ff); style_axes(ax,CLR); hold(ax,'on');

            for k=1:nL
                c   = colors{mod(k-1,numel(colors))+1};
                fT  = lookup(dev_data,'GM_CGG','GM_ID',gmid, ...
                      'L',State.L_array(k),'VDS',State.VDS_target)/(2*pi);
                FoM = gmid(:).*fT(:)/1e9;
                plot(ax,gmid,FoM,'Color',c,'LineWidth',2.2,'Tag','data_curve');
                leg{k}=sprintf('L = %g um', State.L_array(k));
            end
            xlabel(ax,'g_m/I_D  (1/V)',           'Color',CLR.ax_fg,'FontSize',10);
            ylabel(ax,'FoM = (g_m/I_D) x f_T  (GHz/V)', 'Color',CLR.ax_fg,'FontSize',10);
            title(ax, sprintf('Speed-Power Trade-off FoM  [%s]',upper(State.current_dev)), ...
                      'Color',CLR.ax_fg,'FontSize',12,'FontWeight','bold');
            lg=legend(ax,leg,'Location','best');
            set(lg,'TextColor',CLR.ax_fg,'Color',CLR.panel,'EdgeColor',CLR.grid);

        % ================================================================
        case 'p'   % Custom plot
            % ----------------------------------------------------------------
            % Actual raw struct fields (from .mat):
            %   VGS-swept : VT  ID  IGD  IGS  GM  GMB  GDS  CGG  CGS
            %               CSG CGD CDG  CGB  CDD CSS
            % Derived by lookup() from raw fields (GM_ID sweep):
            %   GM_GDS  GM_CGG  CGG_W  CGD_W  CDD_W  ID_W  GDS_W
            % Fields that MUST use VGS sweep (not meaningful vs gm/ID):
            %   VT  ID  GM  GMB  GDS  CGG  CGS  CSG  CGD  CDG  CGB  CDD  CSS
            % ----------------------------------------------------------------

            % Raw struct fields that exist in the .mat (VGS-indexed)
            raw_vgs = {'VT','ID','IGD','IGS','GM','GMB','GDS', ...
                       'CGG','CGS','CSG','CGD','CDG','CGB','CDD','CSS'};
            % Derived fields computed by lookup() vs GM_ID
            raw_gmid = {'GM_GDS','GM_CGG','CGG_W','CGD_W','CDD_W', ...
                        'ID_W','GDS_W','IGD_W','IGS_W'};

            % Build a clean custom dialog with description panel
            % using a proper figure instead of inputdlg hint-row hack
            [y_var, cust_L, cust_vds, dlg_ok] = custom_plot_dialog(CLR);
            if ~dlg_ok, return; end

            % Auto-detect which axis to use based on field type
            % Raw struct fields -> VGS sweep; derived fields -> GM_ID sweep
            use_vgs = any(strcmp(y_var, raw_vgs));

            if isempty(cust_L)
                errordlg('Invalid length format.','Input Error'); return;
            end
            isN    = strcmp(State.current_dev,'nch');
            colors = CLR.nmos_lines; if ~isN, colors=CLR.pmos_lines; end
            leg    = cell(1,numel(cust_L));

            nf = figure('Name',sprintf('Custom: %s  [%s]',y_var,upper(State.current_dev)), ...
                        'Color',CLR.bg,'Position',[160 130 720 480]);
            set(nf,'WindowKeyPressFcn',@(f,e) cadence_shortcuts(f,e));
            setappdata(nf,'State',State);
            ax = axes('Parent',nf); style_axes(ax,CLR); hold(ax,'on');

            if use_vgs
                % ---- VGS sweep (raw struct fields) -------------------------
                vgs_vec = linspace(0.0, 1.2, 241);   % 5 mV steps
                for k = 1:numel(cust_L)
                    c = colors{mod(k-1,numel(colors))+1};
                    try
                        yd = lookup(dev_data, y_var, 'VGS', vgs_vec, ...
                                    'L', cust_L(k), 'VDS', cust_vds);
                        % Normalize per-width if raw current/charge field
                        W_ref = dev_data.W;   % reference width in struct
                        if any(strcmp(y_var,{'ID','GM','GMB','GDS', ...
                                             'CGG','CGS','CSG','CGD', ...
                                             'CDG','CGB','CDD','CSS'}))
                            yd = yd / W_ref;  % normalize to per-um
                        end
                        plot(ax, vgs_vec, yd, 'Color',c, 'LineWidth',2.2, ...
                             'Tag','data_curve');
                        leg{k} = sprintf('L = %g um', cust_L(k));
                    catch ME
                        msg1 = sprintf('Cannot plot "%s" at L=%g.', y_var, cust_L(k));
                        msg2 = 'Check field name. Raw VGS fields:';
                        msg3 = 'VT ID GM GMB GDS CGG CGS CGD CDG CGB CDD CSS';
                        errordlg([msg1 char(10) msg2 char(10) msg3],'Plot Error');
                        close(nf); return;
                    end
                end
                xlabel(ax,'V_{GS}  (V)','Color',CLR.ax_fg,'FontSize',11);

            else
                % ---- GM_ID sweep (derived lookup fields) -------------------
                gmid = State.gm_id_range;
                for k = 1:numel(cust_L)
                    c = colors{mod(k-1,numel(colors))+1};
                    try
                        yd = lookup(dev_data, y_var, 'GM_ID', gmid, ...
                                    'L', cust_L(k), 'VDS', cust_vds);
                        if strcmp(y_var,'GM_CGG'), yd = yd / (2*pi*1e9); end
                        plot(ax, gmid, yd, 'Color',c, 'LineWidth',2.2, ...
                             'Tag','data_curve');
                        leg{k} = sprintf('L = %g um', cust_L(k));
                    catch ME
                        msg1 = sprintf('Cannot plot "%s" at L=%g.', y_var, cust_L(k));
                        msg2 = 'Derived gm/ID fields:';
                        msg3 = 'GM_GDS  GM_CGG  CGG_W  CGD_W  CDD_W  ID_W';
                        msg4 = 'For raw struct fields use VGS sweep:';
                        msg5 = 'VT  ID  GM  GMB  GDS  CGG  CGD  CDD  CSS';
                        errordlg([msg1 char(10) char(10) msg2 char(10) msg3 ...
                                  char(10) msg4 char(10) msg5],'Plot Error');
                        close(nf); return;
                    end
                end
                xlabel(ax,'g_m/I_D  (1/V)','Color',CLR.ax_fg,'FontSize',11);
            end

            % Y axis label -- smart units based on field
            ylabels_map = { ...
                'GM_CGG','f_T (GHz)'; ...
                'ID_W',  'I_D/W (A/um)'; ...
                'VT',    'V_T (V)'; ...
                'ID',    'I_D/W (A/um)'; ...
                'GM',    'g_m/W (S/um)'; ...
                'GMB',   'g_mb/W (S/um)'; ...
                'GDS',   'g_ds/W (S/um)'; ...
                'CGG',   'C_gg/W (F/um)'; ...
                'CGD',   'C_gd/W (F/um)'; ...
                'CDD',   'C_dd/W (F/um)'; ...
                'CSS',   'C_ss/W (F/um)'; ...
            };
            ylab_idx = strcmp(ylabels_map(:,1), y_var);
            if any(ylab_idx)
                ylabel(ax, ylabels_map{ylab_idx,2}, ...
                    'Interpreter','none','Color',CLR.ax_fg,'FontSize',11);
            else
                ylabel(ax, y_var,'Interpreter','none','Color',CLR.ax_fg,'FontSize',11);
            end

            % Log scale for current/capacitance fields
            if any(strcmp(y_var,{'ID_W','ID','CGG','CGD','CDD','CSS','GM','GDS'}))
                set(ax,'YScale','log');
            end

            x_desc = 'gm/ID'; if use_vgs, x_desc = 'VGS'; end
            title(ax, sprintf('%s vs %s  (VDS=%.2fV) [%s]', ...
                y_var, x_desc, cust_vds, upper(State.current_dev)), ...
                'Interpreter','none','Color',CLR.ax_fg,'FontSize',12,'FontWeight','bold');
            lg = legend(ax, leg, 'Location','best');
            set(lg,'TextColor',CLR.ax_fg,'Color',CLR.panel,'EdgeColor',CLR.grid,'FontSize',10);

        % ================================================================
        case 's'   % Auto-sizing
            ans_ = inputdlg({'Target g_m (uS):'}, ...
                'Auto-Sizing  (fixed L array)',[1 40],{'1000'});
            if isempty(ans_), return; end
            tgt_gm   = str2double(ans_{1})*1e-6;
            tgt_gmid = x_val;
            ID_req   = tgt_gm/tgt_gmid;

            rows = {};
            for k=1:numel(State.L_array)
                idw  = lookup(dev_data,'ID_W', 'GM_ID',tgt_gmid,'L',State.L_array(k),'VDS',State.VDS_target);
                W    = ID_req/idw;
                vgs  = lookupVGS(dev_data,'GM_ID',tgt_gmid,'L',State.L_array(k),'VDS',State.VDS_target);
                cggw = lookup(dev_data,'CGG_W','GM_ID',tgt_gmid,'L',State.L_array(k),'VDS',State.VDS_target);
                fT   = (tgt_gm/(2*pi*(cggw*W)))/1e9;
                rows{end+1} = sprintf(' %-6.3f  %-8.2f  %-9.2f  %-8.3f  %-9.2f  %-8.3f', ...
                    State.L_array(k), W, ID_req*1e6, vgs, cggw*W*1e15, fT);
            end
            hdr = sprintf('%-6s  %-8s  %-9s  %-8s  %-9s  %-8s', ...
                'L(um)','W(um)','ID(uA)','VGS(V)','Cgg(fF)','fT(GHz)');
            rep = build_report('AUTO-SIZING REPORT', ...
                sprintf('Target gm=%.2fuS  |  gm/ID=%.1f V^-1  |  ID=%.2fuA', ...
                    tgt_gm*1e6, tgt_gmid, ID_req*1e6), ...
                upper(State.current_dev), hdr, rows);
            fprintf('\n%s',rep);
            State.last_design_report = rep;
            setappdata(fig,'State',State);
            show_text_window(rep,'Auto-Sizing Report',CLR);

        % ================================================================
        case 'd'   % Exact sizing
            ans_ = inputdlg( ...
                {'gm/ID (1/V):','Target I_D (uA):','V_DS (V):','Target Gain (V/V):'}, ...
                'Exact Sizing',[1 44], ...
                {num2str(round(x_val,1)),'50',num2str(State.VDS_target),'20'});
            if isempty(ans_), return; end
            req_gmid = str2double(ans_{1});
            req_id   = str2double(ans_{2})*1e-6;
            req_vds  = str2double(ans_{3});
            req_gain = str2double(ans_{4});

            dense_L = 0.06:0.005:1.0;
            gain_L  = lookup(dev_data,'GM_GDS','GM_ID',req_gmid,'L',dense_L,'VDS',req_vds);

            body = '';
            if req_gain < min(gain_L) || req_gain > max(gain_L)
                body = sprintf( ...
                    ' [WARNING] Gain %.1f V/V is not achievable at gm/ID=%.1f\n Achievable range: %.1f ... %.1f V/V', ...
                    req_gain, req_gmid, min(gain_L), max(gain_L));
            else
                [gu,si] = unique(gain_L);  Lu = dense_L(si);
                req_L   = interp1(gu,Lu,req_gain,'linear');
                idw     = lookup(dev_data,'ID_W', 'GM_ID',req_gmid,'L',req_L,'VDS',req_vds);
                req_W   = req_id/idw;
                req_vgs = lookupVGS(dev_data,'GM_ID',req_gmid,'L',req_L,'VDS',req_vds);
                req_gm  = req_gmid*req_id;
                cggw    = lookup(dev_data,'CGG_W','GM_ID',req_gmid,'L',req_L,'VDS',req_vds);
                req_fT  = req_gm/(2*pi*cggw*req_W);
                body = sprintf( ...
                    ' L        : %8.4f  um\n W        : %8.2f  um\n g_m      : %8.2f  uS\n V_GS     : %8.3f  V\n f_T      : %8.3f  GHz\n Gain     : %8.2f  V/V  (%.1f dB)', ...
                    req_L, req_W, req_gm*1e6, req_vgs, req_fT/1e9, req_gain, 20*log10(req_gain));
            end
            rep = build_report('EXACT SIZING REPORT', ...
                sprintf('gm/ID=%.1f  ID=%.1fuA  VDS=%.2fV  Gain=%.1fV/V', ...
                    req_gmid,req_id*1e6,req_vds,req_gain), ...
                upper(State.current_dev), '', {body});
            fprintf('\n%s',rep);
            State.last_design_report = rep;
            setappdata(fig,'State',State);
            show_text_window(rep,'Exact Sizing Report',CLR);

        % ================================================================
        case 'i'   % Complete Transistor Profiler
            ans_ = inputdlg( ...
                {'gm/ID (1/V):','Target I_D (uA):', ...
                 'Length L (um):','V_DS (V):','V_SB (V):'}, ...
                'Transistor Profiler',[1 46], ...
                {num2str(round(x_val,1)),'50','0.5', ...
                 num2str(State.VDS_target),'0'});
            if isempty(ans_), return; end
            req_gmid = str2double(ans_{1});
            req_id   = str2double(ans_{2})*1e-6;
            req_L    = str2double(ans_{3});
            req_vds  = str2double(ans_{4});
            req_vsb  = str2double(ans_{5});

            try
                id_w    = lookup(dev_data,'ID_W',  'GM_ID',req_gmid,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                req_W   = req_id / id_w;
                req_vgs = lookupVGS(dev_data,'GM_ID',req_gmid,'L',req_L,'VDS',req_vds,'VSB',req_vsb);

                % ---- VTH: read directly from VT LUT at the operating VGS ----
                % VT is stored as VT(VGS, VDS, VSB, L) in the struct.
                % We already know req_vgs, so interpolate at that exact point.
                req_vth = lookup(dev_data,'VT','VGS',req_vgs,'L',req_L,'VDS',req_vds,'VSB',req_vsb);

                % ---- VDSAT: computed exactly from LUT data -------------------
                % VDSAT = 2*ID / GM  (exact identity from simulation, no approx)
                % Both ID and GM are raw 4-D fields swept vs VGS.
                req_id_raw  = lookup(dev_data,'ID', 'VGS',req_vgs,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                req_gm_raw  = lookup(dev_data,'GM', 'VGS',req_vgs,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                req_vdsat   = 2 * req_id_raw / req_gm_raw;
                req_gm    = req_gmid * req_id;
                gain      = lookup(dev_data,'GM_GDS','GM_ID',req_gmid,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                req_gds   = req_gm / gain;
                cgg_w     = lookup(dev_data,'CGG_W','GM_ID',req_gmid,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                cgd_w     = lookup(dev_data,'CGD_W','GM_ID',req_gmid,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                cdd_w     = lookup(dev_data,'CDD_W','GM_ID',req_gmid,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                req_cgg   = abs(cgg_w)*req_W;
                req_cgd   = abs(cgd_w)*req_W;
                req_cdd   = abs(cdd_w)*req_W;
                req_fT    = req_gm/(2*pi*req_cgg);
                req_vov   = req_vgs - req_vth;

                % Curves across gm/ID for mini-plots
                gmv  = State.gm_id_range;
                fTv  = lookup(dev_data,'GM_CGG','GM_ID',gmv,'L',req_L,'VDS',req_vds,'VSB',req_vsb)/(2*pi);
                Avv  = lookup(dev_data,'GM_GDS','GM_ID',gmv,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                idwv = lookup(dev_data,'ID_W',  'GM_ID',gmv,'L',req_L,'VDS',req_vds,'VSB',req_vsb);
                FoMv = gmv(:).*fTv(:)/1e9;

            catch ME
                errordlg(sprintf('Profiler lookup failed:\n%s',ME.message),'Error');
                return;
            end

            % ---- Build text report  (ASCII only -- no Unicode) ----------
            rep = build_profiler_report(State.current_dev, ...
                req_gmid, req_id, req_L, req_vds, req_vsb, ...
                req_W, req_vgs, req_vth, req_vov, req_vdsat, ...
                req_gm, req_gds, gain, req_fT, ...
                req_cgg, req_cgd, req_cdd);

            fprintf('\n%s',rep);
            State.last_design_report = rep;
            setappdata(fig,'State',State);

            % ---- Launch profiler window --------------------------------
            show_profiler_window(State, rep, ...
                req_gmid, req_id, req_L, req_vds, req_vsb, ...
                req_W, req_vgs, req_vth, req_vov, req_vdsat, ...
                req_fT, gain, req_gm, req_gds, ...
                req_cgg, req_cgd, req_cdd, ...
                gmv, fTv, Avv, idwv, FoMv);

        % ================================================================
        case 'e'   % Export
            if strcmp(State.last_design_report,'No design generated yet.')
                errordlg('Generate a design first (S, D, or I).','Export Error');
                return;
            end
            ans_ = inputdlg({'Block name (e.g. M1_TailCurrent):'}, ...
                'Export Log',[1 40],{'M1_Block'});
            if isempty(ans_), return; end
            fid = fopen('Design_Log.txt','a');
            fprintf(fid,'\n%s\n BLOCK: %s  |  DEV: %s  |  %s\n', ...
                repmat('=',1,65), upper(strtrim(ans_{1})), ...
                upper(State.current_dev), datestr(now,'yyyy-mm-dd HH:MM'));
            fprintf(fid,'%s',State.last_design_report);
            fclose(fid);
            fprintf('---> Appended to Design_Log.txt\n');
    end
end

% =========================================================================
%  PROFILER WINDOW  -- fully redesigned professional layout
%
%  Layout (1540 x 720 px logical):
%  +------------------+------------------------------------------+--------+
%  |                  |   fT plot        |   Gain plot            |        |
%  |  Text report     |------------------+------------------------|  Para- |
%  |  (scrollable,    |   ID/W plot      |   FoM plot             |  meter |
%  |   copyable)      |                  |                        |  card  |
%  +------------------+------------------------------------------+--------+
%
%  Column widths (normalized):  0.22 | 0.535 | 0.215
%  Plot margins handled via OuterPosition to avoid label clipping.
% =========================================================================
function show_profiler_window(State, rep, ...
        req_gmid, req_id, req_L, req_vds, req_vsb, ...
        req_W, req_vgs, req_vth, req_vov, req_vdsat, ...
        req_fT, gain, req_gm, req_gds, ...
        req_cgg, req_cgd, req_cdd, ...
        gmv, fTv, Avv, idwv, FoMv)

    CLR   = State.CLR;
    isN   = strcmp(State.current_dev,'nch');
    dname = 'NMOS'; if ~isN, dname='PMOS'; end
    lc    = CLR.nmos_lines{1}; if ~isN, lc=CLR.pmos_lines{1}; end
    lc2   = CLR.nmos_lines{3}; if ~isN, lc2=CLR.pmos_lines{3}; end

    % ---- Figure ----------------------------------------------------------
    pf = figure( ...
        'Name',    sprintf('Transistor Profiler  [%s]   L = %.4f um   VDS = %.2f V   VSB = %.2f V', ...
                           dname, req_L, req_vds, req_vsb), ...
        'Color',   CLR.bg, ...
        'Position',[40 40 1540 720], ...
        'NumberTitle','off');
    set(pf,'WindowKeyPressFcn',@(f,e) cadence_shortcuts(f,e));
    setappdata(pf,'State',State);

    % ======================================================================
    % COLUMN 1 -- Scrollable text report
    % ======================================================================
    uicontrol(pf,'Style','edit','Max',40,'Min',1, ...
        'Units','normalized','Position',[0.005 0.005 0.240 0.990], ...
        'String',        strsplit(rep, newline), ...
        'FontName',      'Courier New', ...
        'FontSize',      12.5, ...
        'HorizontalAlignment','left', ...
        'BackgroundColor', CLR.panel, ...
        'ForegroundColor', [0.75 0.95 0.65], ...
        'Enable',        'inactive');

    % ======================================================================
    % COLUMN 2 -- 2 x 2 plot grid
    % Outer positions given to axes; MATLAB trims to tight inner pos.
    % Gap between rows/columns: 0.015 normalized
    % ======================================================================
    % Shared dimensions
    px0 = 0.250;   % left edge of plot area (shifted right for wider text panel)
    pw  = 0.260;   % plot width  (outer)
    ph  = 0.430;   % plot height (outer)
    py_top = 0.535; % bottom of top row
    py_bot = 0.040; % bottom of bottom row
    gap = 0.015;   % horizontal gap between plots

    % Outer positions: [left bottom width height]
    ppos = { [px0,          py_top, pw, ph], ...   TL: fT
             [px0+pw+gap,   py_top, pw, ph], ...   TR: Gain
             [px0,          py_bot, pw, ph], ...   BL: ID/W
             [px0+pw+gap,   py_bot, pw, ph] };     % BR: FoM

    y_data   = {fTv/1e9,       Avv,              idwv,            FoMv};
    y_labels = {'f_T  (GHz)',  'Gain  (V/V)',    'I_D/W  (A/um)', 'FoM  (GHz/V)'};
    titls    = {'Transit Frequency  f_T', ...
                'Intrinsic Gain  g_m / g_{ds}', ...
                'Current Density  I_D/W', ...
                'Speed-Power FoM'};
    use_log  = [false false true false];
    % y-values at operating point for annotation placement
    yi_all   = zeros(1,4);

    ax_all = gobjects(1,4);
    for k = 1:4
        ax = axes('Parent',pf, 'Units','normalized', ...
                  'OuterPosition', ppos{k});
        style_axes_pro(ax, CLR);
        hold(ax,'on');

        % Main curve -- gradient effect: two overlapping lines
        plot(ax, gmv, y_data{k}, 'Color',lc2, 'LineWidth',3.5, ...
             'Tag','data_curve');
        plot(ax, gmv, y_data{k}, 'Color',lc,  'LineWidth',2.0, ...
             'Tag','data_curve');

        if use_log(k), set(ax,'YScale','log'); end

        % Vertical operating-point line
        xline(ax, req_gmid, 'Color',CLR.marker_v, 'LineWidth',1.4, ...
              'Label', sprintf(' %.1f ', req_gmid));

        % Operating-point dot + value label
        yi = interp1(gmv, y_data{k}, req_gmid,'linear');
        yi_all(k) = yi;
        plot(ax, req_gmid, yi, 'o', ...
             'Color',     CLR.op_dot, ...
             'MarkerFaceColor', CLR.op_dot, ...
             'MarkerEdgeColor', [1 1 1], ...
             'MarkerSize', 9, ...
             'LineWidth',  1.2);

        % Smart label placement: above if in lower half of y-range
        yl_rng = ylim(ax);
        va = 'bottom'; if yi < mean(yl_rng), va = 'top'; end
        offset_str = '  ';
        if use_log(k)
            fmt = '  %.3g';
        else
            fmt = '  %.4g';
        end
        text(ax, req_gmid, yi, sprintf(fmt, yi), ...
             'Color',             CLR.op_dot, ...
             'FontSize',          9.5, ...
             'FontWeight',        'bold', ...
             'VerticalAlignment', va, ...
             'BackgroundColor',   CLR.bg, ...
             'Margin',            1);

        % Axis labels -- only bottom row gets x label
        if k >= 3
            xlabel(ax, 'g_m/I_D  (1/V)', ...
                   'Color',CLR.ax_fg,'FontSize',10,'FontWeight','normal');
        else
            set(ax,'XTickLabel',[]);
        end
        ylabel(ax, y_labels{k}, 'Color',CLR.ax_fg,'FontSize',10);
        title(ax,  titls{k},    'Color',CLR.ax_fg,'FontSize',10.5, ...
              'FontWeight','bold');

        % x-axis shared range annotation on top plots
        if k <= 2
            xl = xlim(ax);
            text(ax, xl(2), yl_rng(2), ...
                 sprintf('gm/ID range: %.0f - %.0f', xl(1), xl(2)), ...
                 'Color',[0.45 0.55 0.65],'FontSize',7.5, ...
                 'HorizontalAlignment','right','VerticalAlignment','top');
        end

        ax_all(k) = ax;
    end

    % Link x-axes so zoom/pan is shared
    linkaxes(ax_all, 'x');

    % ======================================================================
    % COLUMN 3 -- Parameter card
    % Clean two-section card: geometry+bias on top, small-signal below
    % ======================================================================
    card_x = px0 + 2*(pw+gap) + 0.010;
    card_w = 1.0 - card_x - 0.004;

    % Card background panel
    annotation(pf,'rectangle',[card_x 0.005 card_w 0.990], ...
        'Color','none', ...
        'FaceColor',[0.08 0.11 0.17], ...
        'FaceAlpha',1.0);

    % Section: header
    annotation(pf,'rectangle',[card_x 0.895 card_w 0.100], ...
        'Color','none','FaceColor',[0.12 0.22 0.35],'FaceAlpha',1.0);
    annotation(pf,'textbox',[card_x 0.895 card_w 0.100], ...
        'String',      sprintf('[%s]   L = %.4f um', dname, req_L), ...
        'Color',       CLR.accent, ...
        'FontName',    'Courier New', ...
        'FontSize',    12.0, ...
        'FontWeight',  'bold', ...
        'EdgeColor',   'none', ...
        'Interpreter', 'none', ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment',  'middle');

    % Parameter rows: {label, value_string, color}
    C_lbl  = CLR.ax_fg;
    C_val  = [0.95 0.95 0.60];   % warm yellow for values
    C_sep  = [0.22 0.30 0.40];   % separator lines
    C_head = [0.55 0.75 0.95];   % section header text

    param_rows = { ...
        'GEOMETRY',         '',                                          'head'; ...
        'W',                sprintf('%.2f um',   req_W),                 C_val; ...
        'ID',               sprintf('%.2f uA',   req_id*1e6),            C_val; ...
        '',                 '',                                          'sep';  ...
        'BIAS',             '',                                          'head'; ...
        'VGS',              sprintf('%.3f V',    req_vgs),               C_val; ...
        'VT',              sprintf('%.3f V',    req_vth),               C_val; ...
        'VOV',              sprintf('%.3f V',    req_vov),               C_val; ...
        'VDSAT',            sprintf('%.3f V',    req_vdsat),             C_val; ...
        'VDS',              sprintf('%.2f V',    req_vds),               C_val; ...
        'VSB',              sprintf('%.2f V',    req_vsb),               C_val; ...
        '',                 '',                                          'sep';  ...
        'SMALL SIGNAL',     '',                                          'head'; ...
        'gm',               sprintf('%.2f uS',   req_gm*1e6),            C_val; ...
        'gds',              sprintf('%.4f uS',   req_gds*1e6),           C_val; ...
        'Gain',             sprintf('%.2f V/V',  gain),                  C_val; ...
        'Gain',             sprintf('%.1f dB',   20*log10(abs(gain))),   C_val; ...
        'fT',               sprintf('%.3f GHz',  req_fT/1e9),            C_val; ...
        '',                 '',                                          'sep';  ...
        'CAPACITANCES',     '',                                          'head'; ...
        'Cgg',              sprintf('%.2f fF',   req_cgg*1e15),          C_val; ...
        'Cgd',              sprintf('%.2f fF',   req_cgd*1e15),          C_val; ...
        'Cdd',              sprintf('%.2f fF',   req_cdd*1e15),          C_val; ...
        'Cgd/Cgg',          sprintf('%.3f',      req_cgd/req_cgg),       C_val; ...
    };

    n_rows  = size(param_rows,1);
    row_h   = 0.885 / n_rows;   % distribute over 88.5% of card height
    y_start = 0.890;             % just below the header band

    for r = 1:n_rows
        lbl  = param_rows{r,1};
        val  = param_rows{r,2};
        kind = param_rows{r,3};

        y_bot = y_start - r * row_h;

        if strcmp(kind,'sep')
            annotation(pf,'line', ...
                [card_x+0.002, card_x+card_w-0.002], ...
                [y_bot+row_h*0.5, y_bot+row_h*0.5], ...
                'Color',C_sep,'LineWidth',0.8);
            continue;
        end

        if strcmp(kind,'head')
            % Section header background stripe
            annotation(pf,'rectangle', ...
                [card_x+0.001, y_bot+row_h*0.08, card_w-0.002, row_h*0.84], ...
                'Color','none','FaceColor',[0.10 0.18 0.28],'FaceAlpha',0.9);
            annotation(pf,'textbox', ...
                [card_x+0.006, y_bot, card_w-0.008, row_h], ...
                'String',      lbl, ...
                'Color',       C_head, ...
                'FontName',    'Courier New', ...
                'FontSize',    10.5, ...
                'FontWeight',  'bold', ...
                'EdgeColor',   'none', ...
                'Interpreter', 'none', ...
                'VerticalAlignment',  'middle', ...
                'HorizontalAlignment','left');
            continue;
        end

        % Label (left-aligned)
        annotation(pf,'textbox', ...
            [card_x+0.006, y_bot, card_w*0.46, row_h], ...
            'String',      lbl, ...
            'Color',       C_lbl, ...
            'FontName',    'Courier New', ...
            'FontSize',    11.0, ...
            'FontWeight',  'normal', ...
            'EdgeColor',   'none', ...
            'Interpreter', 'none', ...
            'VerticalAlignment',  'middle', ...
            'HorizontalAlignment','left');

        % Value (right-aligned)
        annotation(pf,'textbox', ...
            [card_x + card_w*0.48, y_bot, card_w*0.50, row_h], ...
            'String',      val, ...
            'Color',       kind, ...
            'FontName',    'Courier New', ...
            'FontSize',    11.0, ...
            'FontWeight',  'bold', ...
            'EdgeColor',   'none', ...
            'Interpreter', 'none', ...
            'VerticalAlignment',  'middle', ...
            'HorizontalAlignment','right');
    end
end

% =========================================================================
%  HELPER -- Professional axes style (tighter than style_axes)
% =========================================================================
function style_axes_pro(ax, CLR)
    set(ax, ...
        'Color',          CLR.panel, ...
        'XColor',         CLR.ax_fg, ...
        'YColor',         CLR.ax_fg, ...
        'GridColor',      CLR.grid, ...
        'MinorGridColor', CLR.grid, ...
        'GridAlpha',      0.45, ...
        'MinorGridAlpha', 0.20, ...
        'TickDir',        'out', ...
        'TickLength',     [0.012 0.025], ...
        'FontSize',       9.5, ...
        'FontName',       'Helvetica', ...
        'LineWidth',      0.9, ...
        'Box',            'off', ...
        'XMinorTick',     'on', ...
        'YMinorTick',     'on');
    grid(ax,'on');
end

% =========================================================================
%  HELPER -- Build profiler text report  (pure ASCII, no Unicode)
% =========================================================================
function rep = build_profiler_report(dev, ...
        gmid, id, L, vds, vsb, ...
        W, vgs, vth, vov, vdsat, ...
        gm, gds, gain, fT, cgg, cgd, cdd)
    d = upper(dev);
    sep = [repmat('=',1,58) newline];
    rep = [ sep ...
        sprintf(' TRANSISTOR PROFILE  [%s]\n', d) ...
        sprintf(' I_D=%.2fuA  L=%.3fum  gm/ID=%.1f  VDS=%.2fV  VSB=%.2fV\n', ...
            id*1e6, L, gmid, vds, vsb) ...
        sep ...
        sprintf(' %-22s: %8.2f  um\n',   'Width  (W)',    W) ...
        sprintf(' %-22s: %8.3f  V\n',    'V_GS',          vgs) ...
        sprintf(' %-22s: %8.3f  V\n',    'V_TH',          vth) ...
        sprintf(' %-22s: %8.3f  V\n',    'V_OV = VGS-VTH',vov) ...
        sprintf(' %-22s: %8.3f  V\n',    'V_DSAT',         vdsat) ...
        sprintf(' %-22s: %8.2f  uS\n',   'g_m',            gm*1e6) ...
        sprintf(' %-22s: %8.4f  uS\n',   'g_ds',           gds*1e6) ...
        sprintf(' %-22s: %8.2f  V/V  (%.1f dB)\n', 'Intrinsic Gain A_v', gain, 20*log10(abs(gain))) ...
        sprintf(' %-22s: %8.3f  GHz\n',  'f_T',            fT/1e9) ...
        sprintf(' %-22s: %8.2f  fF\n',   'C_gg',           cgg*1e15) ...
        sprintf(' %-22s: %8.2f  fF\n',   'C_gd',           cgd*1e15) ...
        sprintf(' %-22s: %8.2f  fF\n',   'C_dd',           cdd*1e15) ...
        sprintf(' %-22s: %8.3f\n',       'C_gd/C_gg ratio',cgd/cgg) ...
        sep ];
end

% =========================================================================
%  HELPER -- Generic text report builder
% =========================================================================
function rep = build_report(title_str, subtitle, dev, hdr, rows)
    sep = [repmat('=',1,65) newline];
    rep = [sep sprintf('  %s  [%s]\n',title_str,dev) ...
           sprintf('  %s\n',subtitle) sep];
    if ~isempty(hdr)
        rep = [rep sprintf(' %s\n',hdr) repmat('-',1,65) newline];
    end
    for k=1:numel(rows)
        rep = [rep rows{k} newline];
    end
    rep = [rep sep];
end

% =========================================================================
%  HELPER -- Minimal text report window
% =========================================================================
function show_text_window(rep, title_str, CLR)
    % Count lines to size window height sensibly (min 14, max 32 lines shown)
    n_lines = numel(strsplit(rep, newline));
    win_h   = min(max(n_lines * 22 + 60, 340), 720);
    rf = figure('Name',title_str,'Color',CLR.bg, ...
                'Position',[200 180 760 win_h], ...
                'MenuBar','none','ToolBar','none', ...
                'NumberTitle','off','Resize','on');
    uicontrol(rf,'Style','edit','Max',40,'Min',1, ...
        'Units','normalized','Position',[0.015 0.015 0.970 0.970], ...
        'String',             strsplit(rep, newline), ...
        'FontName',           'Courier New', ...
        'FontSize',           12.5, ...
        'HorizontalAlignment','left', ...
        'BackgroundColor',    CLR.panel, ...
        'ForegroundColor',    [0.82 0.95 0.75], ...
        'Enable',             'inactive');
end

% =========================================================================
%  HELPER -- Custom Plot dialog  (clean UI, no confusing hint rows)
% =========================================================================
function [y_var, cust_L, cust_vds, ok] = custom_plot_dialog(CLR)
    ok = false; y_var = ''; cust_L = []; cust_vds = 0.6;

    % --- Build dialog figure -------------------------------------------
    d = figure('Name','Custom Plot', ...
               'Color',CLR.panel, ...
               'Position',[300 250 500 420], ...
               'NumberTitle','off', ...
               'MenuBar','none','ToolBar','none', ...
               'Resize','off');

    bg  = CLR.panel;
    fg  = CLR.ax_fg;
    acc = [0.27 0.73 1.00];
    fn  = 'Courier New';

    % Title bar
    uicontrol(d,'Style','text','Units','normalized','Position',[0 0.88 1 0.10], ...
        'String','Custom Variable Plot', ...
        'FontName',fn,'FontSize',13,'FontWeight','bold', ...
        'BackgroundColor',[0.10 0.18 0.28],'ForegroundColor',acc);

    % ---- Field reference table (read-only info box) -------------------
    uicontrol(d,'Style','text','Units','normalized','Position',[0.03 0.48 0.94 0.38], ...
        'String',{ ...
            '  gm/ID sweep  (x-axis = gm/ID, auto-selected):', ...
            '    GM_GDS   GM_CGG   CGG_W   CGD_W   CDD_W   ID_W', ...
            ' ', ...
            '  VGS sweep  (x-axis = VGS, auto-selected):', ...
            '    VT   ID   GM   GMB   GDS   CGG   CGD   CDD   CSS', ...
            ' ', ...
            '  Just type the name -- the sweep axis is automatic.'}, ...
        'FontName',fn,'FontSize',10, ...
        'HorizontalAlignment','left', ...
        'BackgroundColor',[0.08 0.12 0.18], ...
        'ForegroundColor',[0.75 0.88 0.75]);

    % ---- Input fields --------------------------------------------------
    % Y variable
    uicontrol(d,'Style','text','Units','normalized','Position',[0.03 0.375 0.35 0.06], ...
        'String','Y Variable:', ...
        'FontName',fn,'FontSize',11,'FontWeight','bold', ...
        'BackgroundColor',bg,'ForegroundColor',fg, ...
        'HorizontalAlignment','left');
    h_yvar = uicontrol(d,'Style','edit','Units','normalized','Position',[0.38 0.375 0.59 0.07], ...
        'String','GM_GDS', ...
        'FontName',fn,'FontSize',11,'FontWeight','bold', ...
        'BackgroundColor',[0.06 0.09 0.14], ...
        'ForegroundColor',[0.95 0.95 0.55]);

    % Length(s)
    uicontrol(d,'Style','text','Units','normalized','Position',[0.03 0.280 0.35 0.06], ...
        'String','L (um):', ...
        'FontName',fn,'FontSize',11,'FontWeight','bold', ...
        'BackgroundColor',bg,'ForegroundColor',fg, ...
        'HorizontalAlignment','left');
    h_L = uicontrol(d,'Style','edit','Units','normalized','Position',[0.38 0.280 0.59 0.07], ...
        'String','0.5', ...
        'FontName',fn,'FontSize',11, ...
        'BackgroundColor',[0.06 0.09 0.14], ...
        'ForegroundColor',[0.95 0.95 0.55]);

    % VDS
    uicontrol(d,'Style','text','Units','normalized','Position',[0.03 0.185 0.35 0.06], ...
        'String','V_DS (V):', ...
        'FontName',fn,'FontSize',11,'FontWeight','bold', ...
        'BackgroundColor',bg,'ForegroundColor',fg, ...
        'HorizontalAlignment','left');
    h_vds = uicontrol(d,'Style','edit','Units','normalized','Position',[0.38 0.185 0.59 0.07], ...
        'String','0.6', ...
        'FontName',fn,'FontSize',11, ...
        'BackgroundColor',[0.06 0.09 0.14], ...
        'ForegroundColor',[0.95 0.95 0.55]);

    % ---- Buttons -------------------------------------------------------
    uicontrol(d,'Style','pushbutton','Units','normalized','Position',[0.20 0.04 0.28 0.10], ...
        'String','Plot', ...
        'FontName',fn,'FontSize',12,'FontWeight','bold', ...
        'BackgroundColor',[0.10 0.35 0.55], ...
        'ForegroundColor',[1 1 1], ...
        'Callback',@do_ok);
    uicontrol(d,'Style','pushbutton','Units','normalized','Position',[0.55 0.04 0.25 0.10], ...
        'String','Cancel', ...
        'FontName',fn,'FontSize',12, ...
        'BackgroundColor',[0.25 0.10 0.10], ...
        'ForegroundColor',[1 1 1], ...
        'Callback',@(~,~) delete(d));

    % Store output variables accessible across callbacks
    res.y_var    = '';
    res.cust_L   = [];
    res.cust_vds = 0.6;
    res.ok       = false;
    setappdata(d,'res',res);

    % OK callback
    function do_ok(~,~)
        r.y_var    = upper(strtrim(get(h_yvar,'String')));
        r.cust_L   = str2num(get(h_L,'String')); %#ok<ST2NM>
        r.cust_vds = str2double(get(h_vds,'String'));
        if isempty(r.cust_L)
            errordlg('Invalid length. Use e.g.  0.5  or  0.06:0.02:0.12','Input Error');
            return;
        end
        r.ok = true;
        setappdata(d,'res',r);
        uiresume(d);
    end

    % Block until user clicks Plot or closes
    uiwait(d);

    if ishandle(d)
        res = getappdata(d,'res');
        y_var    = res.y_var;
        cust_L   = res.cust_L;
        cust_vds = res.cust_vds;
        ok       = res.ok;
        delete(d);
    end
end

% =========================================================================
%  HELPER -- Style an axes to match dark theme
% =========================================================================
function style_axes(ax, CLR)
    set(ax, ...
        'Color',          CLR.panel, ...
        'XColor',         CLR.ax_fg, ...
        'YColor',         CLR.ax_fg, ...
        'GridColor',      CLR.grid, ...
        'MinorGridColor', CLR.grid, ...
        'GridAlpha',      0.5, ...
        'TickDir',        'out', ...
        'FontSize',       9.5, ...
        'FontName',       'Helvetica', ...
        'LineWidth',      0.8, ...
        'Box',            'off');
    grid(ax,'on');
end

% =========================================================================
%  DRAG -- Vertical
% =========================================================================
function startDragV(~, fig, cid)
    set(fig,'WindowButtonMotionFcn',{@dragV,fig,cid},'WindowButtonUpFcn',@stopDrag);
end
function dragV(~,~,fig,cid)
    ax=gca; nx=get(ax,'CurrentPoint'); nx=nx(1,1);
    xls = findobj(fig,'Tag',['v_cursor_' cid]);
    for kx=1:numel(xls)
        xls(kx).Value=nx;
        xls(kx).Label=sprintf('  gm/ID=%.2f  ',nx);
    end
    updateVI(fig,cid,nx);
end
function updateVI(fig,cid,nx)
    allax = findobj(fig,'Type','axes');
    marks = findobj(fig,'Tag',['v_mark_' cid]);
    texts = findobj(fig,'Tag',['v_text_' cid]);
    idx=1;
    for i=1:numel(allax)
        for dl=findobj(allax(i),'Tag','data_curve')'
            xd=dl.XData; yd=dl.YData;
            if nx>=min(xd)&&nx<=max(xd)
                [xu,iu]=unique(xd); yu=yd(iu);
                yi=interp1(xu,yu,nx,'linear');
                marks(idx).XData=nx; marks(idx).YData=yi;
                texts(idx).Position=[nx yi 0];
                texts(idx).String=sprintf(' %.3g',yi);
            else
                marks(idx).XData=NaN; marks(idx).YData=NaN; texts(idx).String='';
            end
            idx=idx+1;
        end
    end
end

% =========================================================================
%  DRAG -- Horizontal
% =========================================================================
function startDragH(~,fig,cid)
    set(fig,'WindowButtonMotionFcn',{@dragH,fig,cid},'WindowButtonUpFcn',@stopDrag);
end
function dragH(~,~,fig,cid)
    ax=gca; ny=get(ax,'CurrentPoint'); ny=ny(1,2);
    yls = findobj(ax,'Tag',['h_cursor_' cid]);
    for ky=1:numel(yls)
        yls(ky).Value=ny;
        yls(ky).Label=sprintf('  y=%.3g  ',ny);
    end
    updateHI(ax,cid,ny);
end
function updateHI(ax,cid,ny)
    marks=findobj(ax,'Tag',['h_mark_' cid]);
    texts=findobj(ax,'Tag',['h_text_' cid]);
    dls=findobj(ax,'Tag','data_curve');
    for j=1:numel(dls)
        xd=dls(j).XData; yd=dls(j).YData;
        [ys,si]=sort(yd); xs=xd(si);
        [yu,iu]=unique(ys); xu=xs(iu);
        if ny>=min(yu)&&ny<=max(yu)
            xi=interp1(yu,xu,ny,'linear');
            marks(j).XData=xi; marks(j).YData=ny;
            texts(j).Position=[xi ny 0];
            texts(j).String=sprintf(' gm/ID=%.2f',xi);
        else
            marks(j).XData=NaN; marks(j).YData=NaN; texts(j).String='';
        end
    end
end
function stopDrag(fig,~)
    set(fig,'WindowButtonMotionFcn','','WindowButtonUpFcn','');
end
