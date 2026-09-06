classdef Interactive_Fit_Path < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        MainAxes          matlab.ui.control.UIAxes
        LoadButton        matlab.ui.control.Button
        LineButton        matlab.ui.control.Button
        ArcButton         matlab.ui.control.Button
        ArcPointCountEdit matlab.ui.control.NumericEditField
        ArcPointCountLabel matlab.ui.control.Label
        ModifyButton      matlab.ui.control.Button
        ModifyCountEdit   matlab.ui.control.NumericEditField
        ModifyCountLabel  matlab.ui.control.Label
        ApplyButton       matlab.ui.control.Button
        UndoButton        matlab.ui.control.Button
        ExportButton      matlab.ui.control.Button
        InstructionLabel  matlab.ui.control.Label
        IndexDisplayLabel matlab.ui.control.Label
    end

    properties (Access = private)
        % Data variables
        RawPath           % [Nx2] Raw Path data holding the full path
        OriginalPath      % Copy of RawPath for full reset if needed
        History           % Cell array to store previous path states for Undo
        
        % Interaction objects arrays (Cell arrays)
        InteractionList   % Cell array of structs, each representing one active Curve/Line/Modify
        % Struct format:
        % .Type : 'Line', 'Arc', or 'Modify'
        % .ROIPoints : array of drawpoint objects
        % .PreviewLine : graphic handle of the plotted preview
        % .PreviewPoints : Nx2 array of the resulting smoothed path points
        % .Listeners : array of event listeners
        % .IndexLabels : text handles for start/end index display
        
        CurrentMode       % 'None', 'MultiMode'
    end
    
    methods (Access = private)
        
        % Button pushed function: LoadButton
        function LoadButtonPushed(app, src, event)
            [file, path] = uigetfile('*.txt;*.csv', 'Select Raw Path Data');
            if isequal(file, 0)
                return; % User canceled
            end
            
            try
                % Read table and convert to array
                dataTable = readtable(fullfile(path, file));
                rawData = table2array(dataTable);
                
                % Assume X is col 1, Y is col 2
                app.RawPath = rawData(:, 1:2);
                app.OriginalPath = app.RawPath;
                app.History = {}; % Clear history
                app.InteractionList = {}; % Clear active tools
                
                app.UpdatePlot();
                app.InstructionLabel.Text = 'Data Loaded. Select Line or Arc tool.';
                
            catch ME
                uialert(app.UIFigure, ['Error loading file: ', ME.message], 'Load Error');
            end
        end
        
        % Plotting function
        function UpdatePlot(app)
            cla(app.MainAxes);
            if isempty(app.RawPath)
                return;
            end
            
            hold(app.MainAxes, 'on');
            
            if ~isempty(app.OriginalPath)
                % Plot the original path faded
                plot(app.MainAxes, app.OriginalPath(:,1), app.OriginalPath(:,2), '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 2, 'DisplayName', 'Original Path');
            end
            
            % Plot the current path
            plot(app.MainAxes, app.RawPath(:,1), app.RawPath(:,2), 'k.-', 'MarkerSize', 5, 'LineWidth', 1, 'DisplayName', 'Current Path');
            axis(app.MainAxes, 'equal');
            grid(app.MainAxes, 'on');
            
            % Legend entries (invisible dummy plots)
            plot(app.MainAxes, NaN, NaN, 'c-', 'LineWidth', 3, 'DisplayName', 'Line');
            plot(app.MainAxes, NaN, NaN, 'm-', 'LineWidth', 3, 'DisplayName', 'Curve');
            plot(app.MainAxes, NaN, NaN, 'bs', 'MarkerSize', 10, 'MarkerFaceColor', 'b', 'DisplayName', 'Start');
            plot(app.MainAxes, NaN, NaN, 'r^', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'DisplayName', 'End');
            legend(app.MainAxes, 'Location', 'northeast');
        end
        
        % Setup interactive points for Line
        function LineButtonPushed(app, src, event)
            if isempty(app.RawPath)
                uialert(app.UIFigure, 'Please load data first.', 'No Data');
                return;
            end
            
            app.CurrentMode = 'MultiMode';
            app.InstructionLabel.Text = 'Drag the two red points to set the line. You can click Add Line or Add Curve again.';
            
            % Initialize two points based on the current view center
            xlims = app.MainAxes.XLim;
            ylims = app.MainAxes.YLim;
            xc = mean(xlims); yc = mean(ylims);
            dx = diff(xlims)/4;
            
            idx1 = app.FindNearestPathIndex([xc-dx, yc]);
            idx2 = app.FindNearestPathIndex([xc+dx, yc]);
            
            % Disambiguate points
            if idx1 == idx2
                idx2 = min(idx1 + 5, size(app.RawPath, 1));
            end
            if idx1 > idx2
                temp = idx1; idx1 = idx2; idx2 = temp;
            end
            
            p1 = app.RawPath(idx1, :);
            p2 = app.RawPath(idx2, :);
            
            % Create Interaction Struct
            newInteraction = struct();
            newInteraction.Type = 'Line';
            newInteraction.ROIPoints = gobjects(2, 1);
            
            newInteraction.ROIPoints(1) = drawpoint(app.MainAxes, 'Position', p1, 'Color', 'r', 'UserData', idx1);
            newInteraction.ROIPoints(2) = drawpoint(app.MainAxes, 'Position', p2, 'Color', 'r', 'UserData', idx2);
            newInteraction.PreviewPoints = [];
            newInteraction.PreviewLine = gobjects(1);
            
            % Add to list
            idx = length(app.InteractionList) + 1;
            app.InteractionList{idx} = newInteraction;
            
            % Initial preview
            app.UpdatePreview(idx);
            
            % Add listeners
            app.InteractionList{idx}.Listeners = addlistener(app.InteractionList{idx}.ROIPoints(1), 'MovingROI', @(src, evt) app.UpdatePreview(idx));
            app.InteractionList{idx}.Listeners(2) = addlistener(app.InteractionList{idx}.ROIPoints(2), 'MovingROI', @(src, evt) app.UpdatePreview(idx));
        end
        
        function UpdatePreview(app, idx)
            interaction = app.InteractionList{idx};
            nPts = length(interaction.ROIPoints);
            
            % 1. Find nearest path index for each point and store in UserData
            pathIndices = zeros(1, nPts);
            for i = 1:nPts
                if strcmp(interaction.Type, 'Modify')
                    udata = interaction.ROIPoints(i).UserData;
                    if isstruct(udata) && isfield(udata, 'Fixed') && udata.Fixed
                        % Fixed targeted index, don't update from position
                        pathIndices(i) = udata.Index;
                    else
                        % Dynamic nearest index
                        pt = interaction.ROIPoints(i).Position;
                        nearestIdx = app.FindNearestPathIndex(pt);
                        pathIndices(i) = nearestIdx;
                        app.InteractionList{idx}.ROIPoints(i).UserData = struct('Index', nearestIdx, 'Fixed', false);
                    end
                else
                    pt = interaction.ROIPoints(i).Position;
                    nearestIdx = app.FindNearestPathIndex(pt);
                    pathIndices(i) = nearestIdx;
                    % Store index in UserData
                    app.InteractionList{idx}.ROIPoints(i).UserData = nearestIdx;
                end
            end
            
            % Sort indices so we know start and end definitively
            sortedIndices = sort(pathIndices);
            idx1 = sortedIndices(1);
            idxEnd = sortedIndices(end);
            
            if idx1 == idxEnd && ~strcmp(interaction.Type, 'Modify')
                return; % Cannot fit a curve/line to a single point
            end
            
            if strcmp(interaction.Type, 'Modify')
                % For modify, preview points are exactly the ROIPoints positions
                pts = zeros(nPts, 2);
                for i = 1:nPts
                    pts(i, :) = interaction.ROIPoints(i).Position;
                end
                app.InteractionList{idx}.PreviewPoints = pts;
                app.UpdatePreviewPlot(idx, idx1, idxEnd);
                
            elseif strcmp(interaction.Type, 'Line')
                p1 = app.RawPath(idx1, :);
                p2 = app.RawPath(idxEnd, :);
                
                totalDist = sqrt((p2(1)-p1(1))^2 + (p2(2)-p1(2))^2);
                numPts = max(3, round(totalDist / 0.3) + 1); % 30cm spacing
                lineX = linspace(p1(1), p2(1), numPts)';
                lineY = linspace(p1(2), p2(2), numPts)';
                
                app.InteractionList{idx}.PreviewPoints = [lineX, lineY];
                app.UpdatePreviewPlot(idx, idx1, idxEnd);
                
            elseif strcmp(interaction.Type, 'Arc')
                % Use actual path index coordinates (snapped path positions)
                % sorted by their corresponding path index order
                [~, sortOrder] = sort(pathIndices);
                inputPoints = zeros(nPts, 2);
                for i = 1:nPts
                    snappedIdx = pathIndices(sortOrder(i));
                    inputPoints(i, :) = app.RawPath(snappedIdx, :);
                end
                
                try
                    dx = diff(inputPoints(:,1));
                    dy = diff(inputPoints(:,2));
                    dist = sqrt(dx.^2 + dy.^2);
                    s_knots = [0; cumsum(dist)];
                    
                    pp_arc_x = spline(s_knots, inputPoints(:,1));
                    pp_arc_y = spline(s_knots, inputPoints(:,2));
                    
                    numPtsToGenerate = max(3, round(s_knots(end) / 0.3) + 1); % 30cm spacing
                    s_new = linspace(0, s_knots(end), numPtsToGenerate);
                    
                    app.InteractionList{idx}.PreviewPoints = [ppval(pp_arc_x, s_new)', ppval(pp_arc_y, s_new)'];
                catch ME
                    app.InstructionLabel.Text = ['Curve generation failed: ', ME.message];
                    return; % Don't try to plot if curve generation failed
                end
                
                app.UpdatePreviewPlot(idx, idx1, idxEnd);
            end
        end
        
        % Setup interactive points for N-Point Curve
        function ArcButtonPushed(app, src, event)
            if isempty(app.RawPath)
                uialert(app.UIFigure, 'Please load data first.', 'No Data');
                return;
            end
            
            nPoints = round(app.ArcPointCountEdit.Value);
            if nPoints < 3
                uialert(app.UIFigure, 'Curve needs at least 3 points.', 'Invalid Number');
                return;
            end
            
            app.CurrentMode = 'MultiMode';
            app.InstructionLabel.Text = sprintf('Drag the %d green points to shape the Curve. You can click buttons again to spawn more.', nPoints);
            
            % Initialize N points evenly spaced across the current view
            xlims = app.MainAxes.XLim;
            ylims = app.MainAxes.YLim;
            
            x_pts = linspace(xlims(1) + diff(xlims)/4, xlims(2) - diff(xlims)/4, nPoints);
            y_pts = repmat(mean(ylims), 1, nPoints);
            
            pathIndices = zeros(1, nPoints);
            for i = 1:nPoints
                pathIndices(i) = app.FindNearestPathIndex([x_pts(i), y_pts(i)]);
            end
            pathIndices = sort(pathIndices);
            
            % Force uniqueness
            for i = 2:nPoints
                if pathIndices(i) <= pathIndices(i-1)
                    pathIndices(i) = min(pathIndices(i-1) + 2, size(app.RawPath, 1));
                end
            end
            
            % Create Interaction Struct
            newInteraction = struct();
            newInteraction.Type = 'Arc';
            newInteraction.ROIPoints = gobjects(nPoints, 1);
            
            for i = 1:nPoints
                pIdx = pathIndices(i);
                pt = app.RawPath(pIdx, :);
                newInteraction.ROIPoints(i) = drawpoint(app.MainAxes, 'Position', pt, 'Color', 'g', 'UserData', pIdx);
            end
            newInteraction.PreviewPoints = [];
            newInteraction.PreviewLine = gobjects(1);
            
            % Add to list
            listIdx = length(app.InteractionList) + 1;
            app.InteractionList{listIdx} = newInteraction;
            
            app.UpdatePreview(listIdx);
            
            for i = 1:nPoints
                app.InteractionList{listIdx}.Listeners(i) = addlistener(app.InteractionList{listIdx}.ROIPoints(i), 'MovingROI', @(src, evt) app.UpdatePreview(listIdx));
            end
        end
        
        % Setup interactive points for Modify Tool
        function ModifyButtonPushed(app, src, event)
            if isempty(app.RawPath)
                uialert(app.UIFigure, 'Please load data first.', 'No Data');
                return;
            end
            
            nPoints = round(app.ModifyCountEdit.Value);
            if nPoints < 1
                return;
            end
            
            % Ask user for input method
            choice = uiconfirm(app.UIFigure, 'Select input method for modifying points:', ...
                'Input Method', 'Options', {'Input Values Manually', 'Interactive Drag', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3);
                
            if strcmp(choice, 'Cancel')
                return;
            end
            
            app.CurrentMode = 'MultiMode';
            app.InstructionLabel.Text = sprintf('Configuring %d points. You can Right-Click yellow points to tweak further.', nPoints);
            
            newInteraction = struct();
            newInteraction.Type = 'Modify';
            newInteraction.ROIPoints = gobjects(nPoints, 1);
            listIdx = length(app.InteractionList) + 1;
            
            if strcmp(choice, 'Input Values Manually')
                % Prompt for exact values for all points
                prompt = cell(nPoints * 3, 1);
                definput = cell(nPoints * 3, 1);
                for i = 1:nPoints
                    prompt{(i-1)*3 + 1} = sprintf('Point %d Target Index:', i);
                    prompt{(i-1)*3 + 2} = sprintf('Point %d New X:', i);
                    prompt{(i-1)*3 + 3} = sprintf('Point %d New Y:', i);
                    
                    % Guess a default target index spread across the path
                    defIdx = max(1, round(i * size(app.RawPath,1) / (nPoints+1)));
                    definput{(i-1)*3 + 1} = num2str(defIdx);
                    definput{(i-1)*3 + 2} = num2str(app.RawPath(defIdx, 1), 10);
                    definput{(i-1)*3 + 3} = num2str(app.RawPath(defIdx, 2), 10);
                end
                
                answer = inputdlg(prompt, 'Manual Values Entry', [1 50], definput);
                if isempty(answer)
                    app.CurrentMode = 'None';
                    app.InstructionLabel.Text = 'Cancelled manual input.';
                    return;
                end
                
                for i = 1:nPoints
                    idxVal = round(str2double(answer{(i-1)*3 + 1}));
                    xVal = str2double(answer{(i-1)*3 + 2});
                    yVal = str2double(answer{(i-1)*3 + 3});
                    if isnan(idxVal) || isnan(xVal) || isnan(yVal) || idxVal < 1 || idxVal > size(app.RawPath, 1)
                        uialert(app.UIFigure, 'Invalid inputs. Aborting.', 'Error');
                        app.CurrentMode = 'None';
                        app.InstructionLabel.Text = 'Invalid input provided.';
                        return;
                    end
                    
                    ptROI = drawpoint(app.MainAxes, 'Position', [xVal, yVal], 'Color', 'y');
                    ptROI.UserData = struct('Index', idxVal, 'Fixed', true);
                    
                    cmenu = uicontextmenu(app.UIFigure);
                    mitem = uimenu(cmenu, 'Text', 'Set Index & Coordinates...', 'MenuSelectedFcn', @(src, evt) app.PointClickedCallback(src, evt, listIdx, ptROI));
                    ptROI.UIContextMenu = cmenu;
                    
                    newInteraction.ROIPoints(i) = ptROI;
                end
            else
                % Interactive drag logic
                xlims = app.MainAxes.XLim;
                ylims = app.MainAxes.YLim;
                
                x_pts = linspace(xlims(1) + diff(xlims)/4, xlims(2) - diff(xlims)/4, nPoints);
                y_pts = repmat(mean(ylims), 1, nPoints);
                
                pathIndices = zeros(1, nPoints);
                for i = 1:nPoints
                    pathIndices(i) = app.FindNearestPathIndex([x_pts(i), y_pts(i)]);
                end
                pathIndices = sort(pathIndices);
                
                % Force uniqueness
                for i = 2:nPoints
                    if pathIndices(i) <= pathIndices(i-1)
                        pathIndices(i) = min(pathIndices(i-1) + 2, size(app.RawPath, 1));
                    end
                end
                
                for i = 1:nPoints
                    pIdx = pathIndices(i);
                    pt = app.RawPath(pIdx, :);
                    ptROI = drawpoint(app.MainAxes, 'Position', pt, 'Color', 'y');
                    ptROI.UserData = struct('Index', pIdx, 'Fixed', false);
                    
                    cmenu = uicontextmenu(app.UIFigure);
                    mitem = uimenu(cmenu, 'Text', 'Set Index & Coordinates...', 'MenuSelectedFcn', @(src, evt) app.PointClickedCallback(src, evt, listIdx, ptROI));
                    ptROI.UIContextMenu = cmenu;
                    
                    newInteraction.ROIPoints(i) = ptROI;
                end
            end
            
            newInteraction.PreviewPoints = [];
            newInteraction.PreviewLine = gobjects(1);
            
            % Add to list
            app.InteractionList{listIdx} = newInteraction;
            
            app.UpdatePreview(listIdx);
            
            for i = 1:nPoints
                app.InteractionList{listIdx}.Listeners(i) = addlistener(app.InteractionList{listIdx}.ROIPoints(i), 'MovingROI', @(src, evt) app.UpdatePreview(listIdx));
            end
        end
        
        % Helper to plot the preview on top of the original
        function UpdatePreviewPlot(app, idx, pathIdx1, pathIdx2)
            interaction = app.InteractionList{idx};
            if isempty(interaction.PreviewPoints)
                return;
            end
            
            % 1. Update or Create Preview Line
            if ~isfield(interaction, 'PreviewLine') || isempty(interaction.PreviewLine) || ~isgraphics(interaction.PreviewLine)
                if strcmp(interaction.Type, 'Line')
                    lc = 'c-'; % Cyan for lines
                    app.InteractionList{idx}.PreviewLine = plot(app.MainAxes, interaction.PreviewPoints(:,1), interaction.PreviewPoints(:,2), lc, 'LineWidth', 3, 'HandleVisibility', 'off');
                elseif strcmp(interaction.Type, 'Arc')
                    lc = 'm-'; % Magenta for arcs
                    app.InteractionList{idx}.PreviewLine = plot(app.MainAxes, interaction.PreviewPoints(:,1), interaction.PreviewPoints(:,2), lc, 'LineWidth', 3, 'HandleVisibility', 'off');
                elseif strcmp(interaction.Type, 'Modify')
                    app.InteractionList{idx}.PreviewLine = plot(app.MainAxes, interaction.PreviewPoints(:,1), interaction.PreviewPoints(:,2), 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y', 'HandleVisibility', 'off');
                    app.InteractionList{idx}.PreviewLine.HitTest = 'off';
                    app.InteractionList{idx}.PreviewLine.PickableParts = 'none';
                end
                interaction = app.InteractionList{idx};
            else
                interaction.PreviewLine.XData = interaction.PreviewPoints(:,1);
                interaction.PreviewLine.YData = interaction.PreviewPoints(:,2);
            end
            
            % 2. Get Active Points Indices
            nPts = length(interaction.ROIPoints);
            idxStrs = strings(1, nPts);
            for i = 1:nPts
                if isstruct(interaction.ROIPoints(i).UserData)
                    idxStrs(i) = num2str(interaction.ROIPoints(i).UserData.Index);
                else
                    idxStrs(i) = num2str(interaction.ROIPoints(i).UserData);
                end
            end
            
            interaction.PreviewLine.HandleVisibility = 'on';
            interaction.PreviewLine.DisplayName = sprintf('Pts: %s', strjoin(idxStrs, ', '));
            
            % 3. Update or Create Start/End Markers
            if ~strcmp(interaction.Type, 'Modify')
                pStart = app.RawPath(pathIdx1, :);
                pEnd = app.RawPath(pathIdx2, :);
                if ~isfield(interaction, 'StartEndMarkers') || isempty(interaction.StartEndMarkers) || any(~isgraphics(interaction.StartEndMarkers))
                    t1 = plot(app.MainAxes, pStart(1), pStart(2), 'bs', 'MarkerSize', 14, 'MarkerFaceColor', 'b', 'LineWidth', 2, 'HitTest', 'off', 'PickableParts', 'none', 'HandleVisibility', 'off');
                    t2 = plot(app.MainAxes, pEnd(1), pEnd(2), 'r^', 'MarkerSize', 14, 'MarkerFaceColor', 'r', 'LineWidth', 2, 'HitTest', 'off', 'PickableParts', 'none', 'HandleVisibility', 'off');
                    app.InteractionList{idx}.StartEndMarkers = [t1, t2];
                else
                    interaction.StartEndMarkers(1).XData = pStart(1);
                    interaction.StartEndMarkers(1).YData = pStart(2);
                    interaction.StartEndMarkers(2).XData = pEnd(1);
                    interaction.StartEndMarkers(2).YData = pEnd(2);
                end
                
                interaction.StartEndMarkers(1).HandleVisibility = 'on';
                interaction.StartEndMarkers(1).DisplayName = sprintf('Start: %d', pathIdx1);
                interaction.StartEndMarkers(2).HandleVisibility = 'on';
                interaction.StartEndMarkers(2).DisplayName = sprintf('End: %d', pathIdx2);
                
                app.IndexDisplayLabel.Text = sprintf('Target Path Indices ->  Start: %d   |   Intermediate/End: %s   |   End: %d', pathIdx1, strjoin(idxStrs, ', '), pathIdx2);
            else
                app.IndexDisplayLabel.Text = sprintf('Modifying Indices ->  %s', strjoin(idxStrs, ', '));
            end
            
            legend(app.MainAxes, 'Location', 'northeast');
        end
        
        % Callback for Right-Click menu to manually enter coordinates
        function PointClickedCallback(app, src, evt, listIdx, pointHandle)
            currentPos = pointHandle.Position;
            if isstruct(pointHandle.UserData)
                currIdx = pointHandle.UserData.Index;
            else
                currIdx = pointHandle.UserData;
            end
            
            prompt = {'Enter Target Path Index:', 'Enter X coordinate:', 'Enter Y coordinate:'};
            dlgtitle = 'Manual Value Entry';
            dims = [1 35];
            definput = {num2str(currIdx), num2str(currentPos(1), 10), num2str(currentPos(2), 10)};
            
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            if ~isempty(answer)
                newIdx = round(str2double(answer{1}));
                newX = str2double(answer{2});
                newY = str2double(answer{3});
                
                if isnan(newIdx) || isnan(newX) || isnan(newY) || newIdx < 1 || newIdx > size(app.RawPath, 1)
                    uialert(app.UIFigure, 'Invalid inputs. Please enter numbers.', 'Error');
                    return;
                end
                
                pointHandle.UserData = struct('Index', newIdx, 'Fixed', true);
                pointHandle.Position = [newX, newY];
                app.UpdatePreview(listIdx);
            end
        end
        
        % Apply all changes
        function ApplyButtonPushed(app, src, event)
            if isempty(app.InteractionList) || strcmp(app.CurrentMode, 'None')
                return;
            end
            
            % Save to history
            app.History{end+1} = app.RawPath;
            
            % Extract segments to apply (use cell array to avoid struct size mismatch)
            segStartIdx = [];
            segEndIdx = [];
            segPts = {};
            
            for k = 1:length(app.InteractionList)
                interaction = app.InteractionList{k};
                if isempty(interaction.PreviewPoints)
                    continue;
                end
                
                % Gather the exact indices from the UserData of the ROI points
                nPts = length(interaction.ROIPoints);
                indices = zeros(1, nPts);
                for i = 1:nPts
                    if isstruct(interaction.ROIPoints(i).UserData)
                        indices(i) = interaction.ROIPoints(i).UserData.Index;
                    else
                        indices(i) = interaction.ROIPoints(i).UserData;
                    end
                end
                
                if strcmp(interaction.Type, 'Modify')
                    % Each point is uniquely applied
                    for i = 1:nPts
                        if isstruct(interaction.ROIPoints(i).UserData)
                            pIdx = interaction.ROIPoints(i).UserData.Index;
                        else
                            pIdx = interaction.ROIPoints(i).UserData;
                        end
                        segStartIdx(end+1) = pIdx; %#ok<AGROW>
                        segEndIdx(end+1) = pIdx; %#ok<AGROW>
                        segPts{end+1} = interaction.PreviewPoints(i, :); %#ok<AGROW>
                    end
                else
                    segStartIdx(end+1) = min(indices); %#ok<AGROW>
                    segEndIdx(end+1) = max(indices); %#ok<AGROW>
                    segPts{end+1} = interaction.PreviewPoints; %#ok<AGROW>
                end
            end
            
            if isempty(segStartIdx)
                return;
            end
            
            % Sort replacements by start index (descending) so earlier modifications don't corrupt later indices
            [~, sortOrd] = sort(segStartIdx, 'descend');
            
            newPath = app.RawPath;
            for k = 1:length(sortOrd)
                si = sortOrd(k);
                % Apply exact index replacement
                newPath = [newPath(1:segStartIdx(si)-1, :); ...
                           segPts{si}; ...
                           newPath(segEndIdx(si)+1:end, :)];
            end
            
            app.RawPath = newPath;
            app.ClearInteractions();
            app.UpdatePlot();
            app.InstructionLabel.Text = sprintf('Modification Applied! Evaluated %d segments.', length(segStartIdx));
        end
        
        function UndoButtonPushed(app, src, event)
            if isempty(app.History)
                app.InstructionLabel.Text = 'Nothing to undo.';
                return;
            end
            
            app.RawPath = app.History{end};
            app.History(end) = [];
            
            app.ClearInteractions();
            app.UpdatePlot();
            app.InstructionLabel.Text = 'Undid last action.';
        end
        
        function ExportButtonPushed(app, src, event)
            if isempty(app.RawPath)
                return;
            end
            [file, path] = uiputfile('*.txt', 'Save Modified Path As');
            if isequal(file, 0)
                return;
            end
            
            fullFileName = fullfile(path, file);
            % Assuming final format requires additional columns or simple X,Y
            % Based on original user script:
            % created_points(:,3) = 0 or 1; created_points(:,4) = 1;
            % Here we just save X,Y but we can pad it if requested
            
            try
                writematrix(app.RawPath, fullFileName, 'Delimiter', '	');
                uialert(app.UIFigure, 'Export successful.', 'Success');
            catch ME
                uialert(app.UIFigure, ['Export Failed: ', ME.message], 'Error');
            end
        end
        
        % Helper to find nearest index in the raw path for a given [x, y]
        function idx = FindNearestPathIndex(app, pt)
            dists = (app.RawPath(:,1) - pt(1)).^2 + (app.RawPath(:,2) - pt(2)).^2;
            [~, idx] = min(dists);
        end
        
        % Clear temporary dragging points and preview lines
        function ClearInteractions(app)
            for k = 1:length(app.InteractionList)
                interaction = app.InteractionList{k};
                % Delete ROI points
                if ~isempty(interaction.ROIPoints)
                    for i = 1:length(interaction.ROIPoints)
                        if isgraphics(interaction.ROIPoints(i))
                            delete(interaction.ROIPoints(i));
                        end
                    end
                end
                % Delete preview line
                if isfield(interaction, 'PreviewLine') && isgraphics(interaction.PreviewLine)
                    delete(interaction.PreviewLine);
                end
                % Delete listeners (use isfield for structs, not isprop)
                if isfield(interaction, 'Listeners') && ~isempty(interaction.Listeners)
                    delete(interaction.Listeners);
                end
                % Delete markers
                if isfield(interaction, 'StartEndMarkers') && ~isempty(interaction.StartEndMarkers)
                    delete(interaction.StartEndMarkers(isgraphics(interaction.StartEndMarkers)));
                end
            end
            
            app.InteractionList = {};
            app.CurrentMode = 'None';
            app.IndexDisplayLabel.Text = 'Selected Indices: None';
        end
        
    end
    
    % Component initialization
    methods (Access = private)
        
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure;
            app.UIFigure.Position = [100 100 1100 650];
            app.UIFigure.Name = 'Interactive Path Fitting Editor';
            
            gl = uigridlayout(app.UIFigure);
            gl.ColumnWidth = {'1x', '1.2x', '1.2x', 'fit', '1.2x', 'fit', '1x', '1x', '1x'};
            gl.RowHeight = {40, '1x', 30, 30};
            
            % Buttons
            app.LoadButton = uibutton(gl, 'push');
            app.LoadButton.Text = 'Load Data';
            app.LoadButton.Layout.Row = 1;
            app.LoadButton.Layout.Column = 1;
            app.LoadButton.ButtonPushedFcn = @app.LoadButtonPushed;
            
            app.LineButton = uibutton(gl, 'push');
            app.LineButton.Text = 'Add Line (2 pts)';
            app.LineButton.Layout.Row = 1;
            app.LineButton.Layout.Column = 2;
            app.LineButton.ButtonPushedFcn = @app.LineButtonPushed;
            
            app.ArcButton = uibutton(gl, 'push');
            app.ArcButton.Text = 'Add Curve (N pts)';
            app.ArcButton.Layout.Row = 1;
            app.ArcButton.Layout.Column = 3;
            app.ArcButton.ButtonPushedFcn = @app.ArcButtonPushed;
            
            % N Points Edit box
            gl2 = uigridlayout(gl, [1 2]);
            gl2.Layout.Row = 1;
            gl2.Layout.Column = 4;
            gl2.ColumnWidth = {'1x', '1x'};
            app.ArcPointCountLabel = uilabel(gl2);
            app.ArcPointCountLabel.Text = 'CrvPts:';
            app.ArcPointCountLabel.HorizontalAlignment = 'right';
            app.ArcPointCountEdit = uieditfield(gl2, 'numeric');
            app.ArcPointCountEdit.Value = 3;
            app.ArcPointCountEdit.Limits = [3 100];
            app.ArcPointCountEdit.RoundFractionalValues = 'on';
            
            % Modify Points Button & Count
            app.ModifyButton = uibutton(gl, 'push');
            app.ModifyButton.Text = 'Modify Specific Pts';
            app.ModifyButton.Layout.Row = 1;
            app.ModifyButton.Layout.Column = 5;
            app.ModifyButton.ButtonPushedFcn = @app.ModifyButtonPushed;
            
            gl3 = uigridlayout(gl, [1 2]);
            gl3.Layout.Row = 1;
            gl3.Layout.Column = 6;
            gl3.ColumnWidth = {'1x', '1x'};
            app.ModifyCountLabel = uilabel(gl3);
            app.ModifyCountLabel.Text = 'ModPts:';
            app.ModifyCountLabel.HorizontalAlignment = 'right';
            app.ModifyCountEdit = uieditfield(gl3, 'numeric');
            app.ModifyCountEdit.Value = 1;
            app.ModifyCountEdit.Limits = [1 50];
            app.ModifyCountEdit.RoundFractionalValues = 'on';
            
            app.ApplyButton = uibutton(gl, 'push');
            app.ApplyButton.Text = 'Apply Change';
            app.ApplyButton.FontWeight = 'bold';
            app.ApplyButton.BackgroundColor = [0.8 1 0.8];
            app.ApplyButton.Layout.Row = 1;
            app.ApplyButton.Layout.Column = 7;
            app.ApplyButton.ButtonPushedFcn = @app.ApplyButtonPushed;
            
            app.UndoButton = uibutton(gl, 'push');
            app.UndoButton.Text = 'Undo';
            app.UndoButton.Layout.Row = 1;
            app.UndoButton.Layout.Column = 8;
            app.UndoButton.ButtonPushedFcn = @app.UndoButtonPushed;
            
            app.ExportButton = uibutton(gl, 'push');
            app.ExportButton.Text = 'Export Path';
            app.ExportButton.FontWeight = 'bold';
            app.ExportButton.Layout.Row = 1;
            app.ExportButton.Layout.Column = 9;
            app.ExportButton.ButtonPushedFcn = @app.ExportButtonPushed;
            
            app.MainAxes = uiaxes(gl);
            title(app.MainAxes, 'Path Preview')
            app.MainAxes.Layout.Row = 2;
            app.MainAxes.Layout.Column = [1 9];
            app.MainAxes.XGrid = 'on';
            app.MainAxes.YGrid = 'on';
            
            % Instruction Label
            app.InstructionLabel = uilabel(gl);
            app.InstructionLabel.Text = 'Welcome. Start by loading a raw data file.';
            app.InstructionLabel.HorizontalAlignment = 'center';
            app.InstructionLabel.FontWeight = 'bold';
            app.InstructionLabel.FontSize = 14;
            app.InstructionLabel.Layout.Row = 3;
            app.InstructionLabel.Layout.Column = [1 9];
            
            app.IndexDisplayLabel = uilabel(gl);
            app.IndexDisplayLabel.Text = 'Selected Indices: None';
            app.IndexDisplayLabel.HorizontalAlignment = 'center';
            app.IndexDisplayLabel.FontColor = [0 0 1];
            app.IndexDisplayLabel.FontSize = 16;
            app.IndexDisplayLabel.FontWeight = 'bold';
            app.IndexDisplayLabel.Layout.Row = 4;
            app.IndexDisplayLabel.Layout.Column = [1 9];
        end
    end
    
    methods (Access = public)
        % Construct app
        function app = Interactive_Fit_Path()
            % Create and configure components
            createComponents(app)
            % Register the app with App Designer
            registerApp(app, app.UIFigure)
            
            % Initialize runtime properties
            app.InteractionList = {};
            app.CurrentMode = 'None';
            app.History = {};
            
            if nargout == 0
                clear app
            end
        end
    end
end
