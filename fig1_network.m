function fig1_network(sys, testFault, saveDir)
% FIG1_NETWORK  系统 + 关键负荷 + 故障线路（Poster 版）

    style_poster();
    C = poster_colors();

    switch sys.nNode
        case 69, xy = layout_ieee69();
        case 33, xy = layout_ieee33();
    end

    fig = figure('Position',[50 50 1600 700]);
    ax  = axes('Parent', fig); hold(ax,'on');

    % ---- 馈线（灰色底）----
    for e = 1:sys.nBranch
        if sys.isTie(e), continue; end
        x1=xy(sys.from(e),1); y1=xy(sys.from(e),2);
        x2=xy(sys.to(e),1);   y2=xy(sys.to(e),2);
        plot(ax,[x1 x2],[y1 y2],'-','Color',C.net,'LineWidth',1.4);
    end

    % ---- 联络开关（橙色虚绕行）----
    tieCnt = struct();
    for e = find(sys.isTie)'
        x1=xy(sys.from(e),1); y1=xy(sys.from(e),2);
        x2=xy(sys.to(e),1);   y2=xy(sys.to(e),2);
        if abs(y1-y2) < 1e-6
            key = sprintf('H_%d',round(y1*100));
            if isfield(tieCnt,key), lvl = tieCnt.(key)+1; else, lvl = 1; end
            tieCnt.(key) = lvl; dy = 0.55*lvl;
            xs=[x1 x1 x2 x2]; ys=[y1 y1+dy y2+dy y2];
        else
            xs=[x1 x2]; ys=[y1 y2];
        end
        plot(ax,xs,ys,'--','Color',[0.95 0.55 0.10],'LineWidth',2.6);
    end

    % ---- 故障线路 ----
    for e = find(testFault)'
        x1=xy(sys.from(e),1); y1=xy(sys.from(e),2);
        x2=xy(sys.to(e),1);   y2=xy(sys.to(e),2);
        plot(ax,[x1 x2],[y1 y2],'-','Color',[1 0.1 0.1],'LineWidth',5.5);
    end

    % ---- 节点（按类型）----
    Pmax = max(sys.Pload_kW);
    for i = 1:sys.nNode
        x = xy(i,1); y = xy(i,2);
        if i == sys.root
            plot(ax,x,y,'s','MarkerSize',22,'MarkerFaceColor',[0.15 0.80 0.25], ...
                 'MarkerEdgeColor','k','LineWidth',1.6);
        elseif strcmp(sys.nodeType{i},'数据中心')
            plot(ax,x,y,'p','MarkerSize',30,'MarkerFaceColor',C.dc, ...
                 'MarkerEdgeColor','k','LineWidth',1.8);
        elseif strcmp(sys.nodeType{i},'医院')
            plot(ax,x,y,'h','MarkerSize',26,'MarkerFaceColor',C.hos, ...
                 'MarkerEdgeColor','k','LineWidth',1.8);
        else
            sz = 8 + 18*(sys.Pload_kW(i)/Pmax)^0.45;
            plot(ax,x,y,'o','MarkerSize',sz,'MarkerFaceColor',[0.45 0.70 1.0], ...
                 'MarkerEdgeColor',[0.05 0.15 0.45],'LineWidth',1.0);
        end
    end

    % ---- 关键节点标注 ----
    for i = find(~cellfun(@isempty, strfind(sys.nodeType, '数据中心')))'
        text(ax, xy(i,1), xy(i,2)-0.35, sprintf('DC@%d',i), ...
             'HorizontalAlignment','center','FontSize',12,'FontWeight','bold', ...
             'Color',C.dc, 'BackgroundColor',[1 1 1 0.8], 'Margin',1);
    end
    for i = find(~cellfun(@isempty, strfind(sys.nodeType, '医院')))'
        text(ax, xy(i,1), xy(i,2)+0.35, sprintf('H@%d',i), ...
             'HorizontalAlignment','center','FontSize',12,'FontWeight','bold', ...
             'Color',C.hos, 'BackgroundColor',[1 1 1 0.8], 'Margin',1);
    end

    axis(ax,'equal'); axis(ax,'off');
    title(ax, sprintf('IEEE %d 节点配电网 | 测试故障线路: %s', ...
          sys.nNode, mat2str(find(testFault)')), 'FontSize',15);

    exportgraphics(fig, fullfile(saveDir,'fig1_network.png'), 'Resolution', 300);
end