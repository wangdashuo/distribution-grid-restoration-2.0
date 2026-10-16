function fig5_crew_timeline(results, sys, cfg, saveDir)
% FIG5_CREW_TIMELINE  各场景的抢修甘特图（支持任意场景数）

    style_poster(); C = poster_colors();
    T = cfg.T;  K = numel(results);

    % 自适应子图网格
    nCol = ceil(sqrt(K));
    nRow = ceil(K / nCol);

    fig = figure('Position',[50 50 1600 800]);

    for k = 1:K
        subplot(nRow, nCol, k); hold on;
        s = results(k).s;

        % 求求解失败的情形
        if isempty(s) || all(isnan(s(:)))
            text(0.5, 0.5, '求解失败', 'Units','normalized', ...
                 'HorizontalAlignment','center','FontSize',13,'Color','r');
            axis off;
            title(results(k).name,'FontSize',10,'Interpreter','none');
            continue;
        end

        [eList, tList] = find(s > 0.5);
        if isempty(eList)
            text(0.5, 0.5, '无修复动作', 'Units','normalized', ...
                 'HorizontalAlignment','center','FontSize',12);
            axis off;
            title(results(k).name,'FontSize',10,'Interpreter','none');
            continue;
        end

        for i = 1:numel(eList)
            e = eList(i); t = tList(i);
            if sys.isTie(e)
                col = [0.95 0.55 0.10];
            elseif strcmp(sys.nodeType(sys.to(e)), '数据中心')
                col = C.dc;
            elseif strcmp(sys.nodeType(sys.to(e)), '医院')
                col = C.hos;
            else
                col = [0.30 0.55 0.85];
            end
            rectangle('Position',[t-1, e-0.4, 1, 0.8], ...
                      'FaceColor', col, 'EdgeColor','k', 'LineWidth', 0.8);
        end

        xlabel('时段');  ylabel('线路编号');
        title(results(k).name, 'FontSize', 10, 'Interpreter','none');
        xlim([0.5 T+0.5]);  xticks(1:T);
        grid on;
    end

    sgtitle('各策略抢修甘特图（紫=DC相关，红=医院相关，橙=联络）', ...
            'FontSize', 15, 'FontWeight','bold');

    exportgraphics(fig, fullfile(saveDir,'fig5_crew_timeline.png'), ...
                   'Resolution', 300);
    fprintf('    → 保存: fig5_crew_timeline.png\n');
end